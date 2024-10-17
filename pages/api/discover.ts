import type { NextApiRequest, NextApiResponse } from 'next';

export default async (req: NextApiRequest, res: NextApiResponse) => {
    const { title, year, plot = 'short' } = req.query;
    const apiKey = '29efbf52'; // Your OMDb API key
    const url = `http://www.omdbapi.com/?apikey=${apiKey}&t=${title}&y=${year}&plot=${plot}`;

    try {
        const response = await fetch(url);
        const data = await response.json();

        if (data.Response === 'True') {
            // Include the poster URL in the response
            const movieData = {
                title: data.Title,
                year: data.Year,
                plot: data.Plot,
                poster: data.Poster, // Include the poster URL
                // Add any other data you need
            };
            res.status(200).json(movieData);
        } else {
            res.status(404).json({ error: data.Error });
        }
    } catch (error) {
        res.status(500).json({ error: 'An error occurred while fetching data' });
    }
};
