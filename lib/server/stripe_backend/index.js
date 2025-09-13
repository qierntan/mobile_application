require('dotenv').config();

const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS', 'PUT', 'DELETE', 'HEAD'],
  allowedHeaders: ['Content-Type', 'Accept', 'Authorization', 'Origin', 'X-Requested-With'],
  credentials: true
}));
app.use(express.json());

// UPDATED: Using port 8081 instead of 8080 because Oracle TNS Listener is using 8080
// Use localhost since both Stripe server and Flutter app are on the same machine
const FLUTTER_SERVER_URL = 'http://localhost:8081';

app.post('/create-checkout-session', async (req, res) => {
  const { amount, description, customer_email, success_url, cancel_url, metadata } = req.body;
  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      customer_email: customer_email,
      metadata: metadata, // Include metadata in the Stripe session
      line_items: [{
        price_data: {
          currency: 'myr',
          product_data: { name: description || 'Invoice Payment' },
          unit_amount: Math.round(amount * 100),
        },
        quantity: 1,
      }],
      mode: 'payment',
      success_url: success_url || 'http://192.168.1.103:4242/success',
      cancel_url: cancel_url || 'http://192.168.1.103:4242/cancel',
    });
    res.json({ url: session.url });
  } catch (e) {
    console.error(e);
    res.status(400).json({ error: e.message });
  }
});

// Helper function to notify Flutter app
async function notifyFlutterApp(invoiceId, customerEmail, sessionId, amountPaid) {
  try {
    console.log('Sending request to Flutter server...');
    console.log('Request data:', {
      invoice_id: invoiceId,
      customer_email: customerEmail,
      session_id: sessionId,
      amount_paid: amountPaid
    });
    
    const response = await fetch(`${FLUTTER_SERVER_URL}/handle-payment-success`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        invoice_id: invoiceId,
        customer_email: customerEmail,
        session_id: sessionId,
        amount_paid: amountPaid
      })
    });

    const responseText = await response.text();
    console.log('Flutter server response status:', response.status);
    console.log('Flutter server response:', responseText);
    
    if (!response.ok) {
      console.error('Failed to notify Flutter app:', {
        status: response.status,
        statusText: response.statusText,
        response: responseText
      });
      return false;
    } else {
      console.log('Successfully notified Flutter app of payment success');
      return true;
    }
  } catch (fetchError) {
    console.error('Error calling Flutter app:', fetchError);
    return false;
  }
}

// Verify payment endpoint
app.post('/verify-payment', async (req, res) => {
  try {
    const { session_id, invoice_id, customer_email } = req.body;
    
    // Verify the payment with Stripe
    const session = await stripe.checkout.sessions.retrieve(session_id);
    
    if (session.payment_status === 'paid') {
      // Call handlePaymentSuccess if we have the required data
      if (invoice_id && customer_email) {
        await notifyFlutterApp(
          invoice_id,
          customer_email,
          session_id,
          session.amount_total / 100
        );
      }
      
      // Send successful response
      res.json({
        status: 'success',
        message: 'Payment verified successfully',
        payment_status: session.payment_status,
        customer_email: session.customer_email,
        amount_total: session.amount_total / 100
      });
    } else {
      res.status(400).json({
        status: 'error',
        message: 'Payment not completed'
      });
    }
  } catch (error) {
    console.error('Error verifying payment:', error);
    res.status(400).json({ 
      status: 'error',
      message: error.message 
    });
  }
});

// Success page route
app.get('/success', async (req, res) => {
  const sessionId = req.query.session_id;
  const invoiceId = req.query.invoice_id;
  const customerEmail = req.query.customer_email;

  try {
    // Verify the payment with Stripe
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    
    if (session.payment_status === 'paid') {
      console.log('Payment verified as paid. Notifying Flutter app...');
      console.log('Invoice ID:', invoiceId);
      console.log('Customer Email:', customerEmail);
      console.log('Session ID:', sessionId);
      
      // Call the Flutter app's handlePaymentSuccess function
      const notificationSuccess = await notifyFlutterApp(
        invoiceId,
        customerEmail,
        sessionId,
        session.amount_total / 100
      );

      // Show success page regardless of Flutter notification status
      res.send(`
        <!DOCTYPE html>
        <html>
          <head>
            <title>Payment Success</title>
            <style>
              body { 
                font-family: Arial; 
                text-align: center; 
                padding-top: 50px; 
                background-color: #f8f9fa;
              }
              .container {
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background: white;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
              }
              .success { 
                color: #4CAF50; 
                font-size: 48px; 
                margin-bottom: 20px; 
              }
              .warning { 
                color: #FF9800; 
                font-size: 14px; 
                margin-top: 20px; 
              }
              .email-info {
                background-color: #e8f5e9;
                padding: 15px;
                border-radius: 5px;
                margin: 20px 0;
                color: #2e7d32;
              }
              .email-icon {
                font-size: 24px;
                margin-bottom: 10px;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="success">✓</div>
              <h1>Payment Successful!</h1>
              <p>Your payment has been processed successfully.</p>
              
              <div class="email-info">
                <div class="email-icon">✉️</div>
                <h3>Payment Confirmation Sent!</h3>
                <p>A detailed payment confirmation has been sent to your email: ${customerEmail}</p>
              </div>

              ${!notificationSuccess ? '<p class="warning">Note: There was a delay in updating your invoice status. Please contact support if needed.</p>' : ''}
              
              <p>Thank you for your payment. You can close this window now.</p>
            </div>
          </body>
        </html>
      `);
    } else {
      res.status(400).send('Payment not completed');
    }
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send('Error processing payment');
  }
});

// Cancel page route
app.get('/cancel', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Payment Cancelled</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #f0f0f0;
          }
          .cancel-container {
            text-align: center;
            padding: 40px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            max-width: 500px;
          }
          .cancel-icon {
            color: #f44336;
            font-size: 48px;
            margin-bottom: 20px;
          }
          h1 {
            color: #333;
            margin-bottom: 20px;
          }
          p {
            color: #666;
            margin-bottom: 15px;
            line-height: 1.5;
          }
        </style>
      </head>
      <body>
        <div class="cancel-container">
          <div class="cancel-icon">x</div>
          <h1>Payment Cancelled</h1>
          <p>Your payment has been cancelled.</p>
          <p>You can close this window and try again.</p>
        </div>
      </body>
    </html>
  `);
});

// Webhook endpoint to handle successful payments
app.post('/webhook', async (req, res) => {
  try {
    const { type, data } = req.body;
    
    if (type === 'checkout.session.completed') {
      const session = data.object;
      
      console.log('Payment completed for session:', session.id);
      console.log('Invoice ID:', session.metadata?.invoice_id);
      console.log('Customer Email:', session.customer_email);
      
      // Call handlePaymentSuccess directly
      if (session.metadata?.invoice_id && session.customer_email) {
        await notifyFlutterApp(
          session.metadata.invoice_id,
          session.customer_email,
          session.id,
          session.amount_total / 100
        );
      } else {
        console.error('Missing invoice_id or customer_email in session metadata');
      }
    }
    
    res.json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(400).send('Webhook Error');
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    server: 'Stripe Payment Server',
    flutter_server_url: FLUTTER_SERVER_URL,
    timestamp: new Date().toISOString()
  });
});

console.log('Configuration:');
console.log('- Stripe server will run on port 4242');
console.log('- Flutter server expected at:', FLUTTER_SERVER_URL);
console.log('- Note: Port 8080 was changed to 8081 because Oracle TNS Listener is using 8080');

app.listen(4242, () => console.log('Server running on port 4242'));