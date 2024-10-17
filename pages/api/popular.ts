import type { NextApiRequest, NextApiResponse } from 'next';

export default async (req: NextApiRequest, res: NextApiResponse) => {
    const { title, type = '', year, page = 1 } = req.query;
    const apiKey = '29efbf52';
    const url = `http://www.omdbapi.com/?apikey=${apiKey}&s=${title}&type=${type}&y=${year}&page=${page}`;

    try {
        const response = await fetch(url);
        const data = await response.json();

        if (data.Response === 'True') {
            res.status(200).json(data.Search);
        } else {
            res.status(404).json({ error: data.Error });
        }
    } catch (error) {
        res.status(500).json({ error: 'An error occurred while fetching data' });
    }
};
