import type { NextApiRequest, NextApiResponse } from 'next';

export default async (req: NextApiRequest, res: NextApiResponse) => {
    const { title, year, plot = 'short' } = req.query;
    const apiKey = '29efbf52';
    const url = `http://www.omdbapi.com/?apikey=${apiKey}&t=${title}&y=${year}&plot=${plot}`;

    try {
        const response = await fetch(url);
        const data = await response.json();

        if (data.Response === 'True') {
            res.status(200).json(data);
        } else {
            res.status(404).json({ error
