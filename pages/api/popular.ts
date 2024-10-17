
import axios from "../../utils/axios";

const apiKey = process.env.OMDB_KEY;  // OMDb API Key

export default async (req, res) => {
  const result = await axios.get('/', {
    params: {
      apikey: apiKey,  // OMDb requires 'apikey'
      s: 'popular',    // Search for popular movies (adjust this to match OMDb behavior)
    },
  });

  res.status(200).json(result.data);
};
