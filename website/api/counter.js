export default async function handler(req, res) {
  // Allow CORS for local development
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  // Prevent Vercel from caching this API route
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const apiKey = process.env.LEMON_SQUEEZY_API_KEY;

  // If the API key isn't set yet (e.g. local dev before you add it to Vercel),
  // we just return a default value so the website doesn't crash.
  if (!apiKey) {
    return res.status(200).json({ count: 0, remaining: 250, error: "Missing LEMON_SQUEEZY_API_KEY" });
  }

  try {
    const response = await fetch('https://api.lemonsqueezy.com/v1/discounts', {
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
        'Authorization': `Bearer ${apiKey}`
      }
    });

    if (!response.ok) {
      throw new Error(`API returned status: ${response.status}`);
    }

    const json = await response.json();
    
    // Find our EARLYBIRD discount code
    const earlybirdDiscount = json.data.find(
      d => d.attributes && d.attributes.code.toUpperCase() === 'EARLYBIRD'
    );

    if (earlybirdDiscount) {
      const discountId = earlybirdDiscount.id;
      const attributes = earlybirdDiscount.attributes || {};
      const maxRedemptions = attributes.max_redemptions || 250;
      
      // Fetch the actual redemptions for this discount
      let usageCount = 0;
      try {
        const redemptionsRes = await fetch(`https://api.lemonsqueezy.com/v1/discount-redemptions?filter[discount_id]=${discountId}`, {
          headers: {
            'Accept': 'application/vnd.api+json',
            'Content-Type': 'application/vnd.api+json',
            'Authorization': `Bearer ${apiKey}`
          }
        });
        
        if (redemptionsRes.ok) {
          const redemptionsJson = await redemptionsRes.json();
          // Use meta total if available, otherwise array length
          usageCount = redemptionsJson.meta?.page?.total ?? redemptionsJson.data?.length ?? 0;
        }
      } catch (e) {
        console.error("Error fetching redemptions:", e);
      }

      const remaining = Math.max(0, maxRedemptions - usageCount);
      
      return res.status(200).json({ 
        count: usageCount, 
        remaining: remaining,
        debug_attributes: attributes 
      });
    }

    // If we couldn't find the code, just return 250 remaining
    return res.status(200).json({ count: 0, remaining: 250, debug: "Code EARLYBIRD not found in API response" });

  } catch (error) {
    console.error("Error fetching LemonSqueezy discounts:", error);
    // On error, fail gracefully but include the error message
    return res.status(200).json({ count: 0, remaining: 250, error: error.message });
  }
}
