export default async function handler(req, res) {
  // Allow CORS for local development
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const apiKey = process.env.LEMON_SQUEEZY_API_KEY;

  // If the API key isn't set yet (e.g. local dev before you add it to Vercel),
  // we just return a default value so the website doesn't crash.
  if (!apiKey) {
    return res.status(200).json({ count: 0, remaining: 250 });
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
      const usageCount = earlybirdDiscount.attributes.usage_count || 0;
      const maxRedemptions = earlybirdDiscount.attributes.max_redemptions || 250;
      const remaining = Math.max(0, maxRedemptions - usageCount);
      
      return res.status(200).json({ count: usageCount, remaining });
    }

    // If we couldn't find the code, just return 250 remaining
    return res.status(200).json({ count: 0, remaining: 250 });

  } catch (error) {
    console.error("Error fetching LemonSqueezy discounts:", error);
    // On error, fail gracefully
    return res.status(200).json({ count: 0, remaining: 250, error: "Failed to fetch" });
  }
}
