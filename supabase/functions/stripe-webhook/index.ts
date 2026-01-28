import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@11.1.0?target=deno'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2022-11-15',
})

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Helper: update profile by stripe customer ID
async function updateProfileByCustomer(customerId: string, updates: Record<string, any>) {
  const { error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('stripe_customer_id', customerId)

  if (error) {
    console.error('Supabase update error:', error)
  } else {
    console.log('Profile updated:', JSON.stringify(updates))
  }
}

// Helper: update profile by email
async function updateProfileByEmail(email: string, updates: Record<string, any>) {
  const { error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('email', email)

  if (error) {
    console.error('Supabase update error:', error)
  } else {
    console.log('Profile updated by email:', JSON.stringify(updates))
  }
}

serve(async (req) => {
  try {
    const signature = req.headers.get('Stripe-Signature')
    if (!signature) {
      return new Response(JSON.stringify({ error: 'No signature' }), { status: 400 })
    }

    const body = await req.text()

    const event = stripe.webhooks.constructEvent(
      body,
      signature,
      Deno.env.get('STRIPE_WEBHOOK_SECRET')!
    )

    console.log('Webhook event received:', event.type)

    // ── Checkout completed (new subscription or one-time payment) ──
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as any
      const customerEmail = session.customer_details?.email

      console.log('Customer email:', customerEmail)
      console.log('Session customer:', session.customer)
      console.log('Session subscription:', session.subscription)

      if (customerEmail) {
        // Use 30 days as default period, subscription.updated will set the real end date
        const periodEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

        await updateProfileByEmail(customerEmail, {
          subscription_status: 'active',
          stripe_customer_id: session.customer,
          current_period_end: periodEnd
        })
      }
    }

    // ── Subscription updated (renewal, plan change, trial end) ──
    if (event.type === 'customer.subscription.updated') {
      const subscription = event.data.object as any
      const customerId = subscription.customer
      const status = subscription.status // active, past_due, canceled, trialing, etc.

      const isActive = status === 'active' || status === 'trialing'

      await updateProfileByCustomer(customerId, {
        subscription_status: isActive ? 'active' : 'expired',
        current_period_end: new Date(subscription.current_period_end * 1000).toISOString()
      })
    }

    // ── Subscription deleted (canceled and period ended) ──
    if (event.type === 'customer.subscription.deleted') {
      const subscription = event.data.object as any
      const customerId = subscription.customer

      await updateProfileByCustomer(customerId, {
        subscription_status: 'canceled',
        current_period_end: new Date().toISOString()
      })
    }

    // ── Invoice payment failed (card declined, insufficient funds) ──
    if (event.type === 'invoice.payment_failed') {
      const invoice = event.data.object as any
      const customerId = invoice.customer

      // Only downgrade if this is a subscription invoice (not a one-time)
      if (invoice.subscription) {
        await updateProfileByCustomer(customerId, {
          subscription_status: 'past_due'
        })
      }
    }

    // ── Invoice paid (successful renewal) ──
    if (event.type === 'invoice.paid') {
      const invoice = event.data.object as any
      const customerId = invoice.customer

      if (invoice.subscription) {
        // Use invoice period end, or 30 days from now as fallback
        const periodEnd = invoice.lines?.data?.[0]?.period?.end
          ? new Date(invoice.lines.data[0].period.end * 1000).toISOString()
          : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

        await updateProfileByCustomer(customerId, {
          subscription_status: 'active',
          current_period_end: periodEnd
        })
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (err) {
    console.error('Webhook error:', err.message)
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
