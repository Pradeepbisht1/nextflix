import axios from "../../utils/axios";

const apiKey = process.env.OMDB_KEY;  // OMDb API Key

export default async (req, res) => {
  const { genre } = req.query;

  try {
    const result = await axios.get('/', {
      params: {
        apikey: apiKey,  // OMDb uses 'apikey'
        s: genre,        // 's' is for searching movies by genre or title
      },
    });
    res.status(200).json(result.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch data from OMDb' });
  }
};
