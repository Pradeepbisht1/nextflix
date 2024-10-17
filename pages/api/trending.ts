import axios from "../../utils/axios";

const apiKey = process.env.OMDB_KEY;  // OMDb API Key

export default async (req, res) => {
  const { type } = req.query;

  try {
    const result = await axios.get('/', {
      params: {
        apikey: apiKey,   // OMDb uses 'apikey'
        s: type,          // 's' for searching trending type (e.g., movie or show type)
      },
    });
    res.status(200).json(result.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch trending data from OMDb' });
  }
};
