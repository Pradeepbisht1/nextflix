import axios from "../../utils/axios";

const apiKey = process.env.OMDB_KEY;  // OMDb API Key

export default async (req, res) => {
  try {
    const result = await axios.get('/', {
      params: {
        apikey: apiKey,   // OMDb uses 'apikey'
        s: 'popular',     // Search term 'popular' (adjust according to OMDb behavior)
      },
    });
    res.status(200).json(result.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch popular movies from OMDb' });
  }
};
