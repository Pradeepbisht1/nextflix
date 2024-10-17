import axios from "../../utils/axios";

const apiKey = process.env.OMDB_KEY;  // OMDb API Key

export default async (req, res) => {
  const { genre } = req.query;
  
  const result = await axios.get('/', {
    params: {
      apikey: apiKey,  // OMDb requires 'apikey'
      s: genre,        // Use 's' for searching by genre or title
    },
  });

  res.status(200).json(result.data);
};

