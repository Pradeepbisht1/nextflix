/* eslint-disable @next/next/no-img-element */
import { useEffect, useState, useContext } from 'react';
import axios from 'axios';

import Button from '../Button';
import { Media } from '../../types';
import { Play, Info } from '../../utils/icons';
import { ModalContext } from '../../context/ModalContext';
import styles from '../../styles/Banner.module.scss';

export default function Banner() {
  const [media, setMedia] = useState<Media>();
  const random = Math.floor(Math.random() * 20); // Random movie selector
  const { setModalData, setIsModal } = useContext(ModalContext);
  const apiKey = process.env.NEXT_PUBLIC_OMDB_API_KEY; // Use your OMDb API key from .env

  const onClick = (data: Media) => {
    setModalData(data);
    setIsModal(true);
  };

  const getMedia = async () => {
    try {
      const result = await axios.get(`http://www.omdbapi.com/?t=Inception&apikey=${apiKey}`);
      setMedia(result.data);
    } catch (error) {
      console.error('Error fetching movie data:', error);
    }
  };

  useEffect(() => {
    getMedia();
  }, []);

  return (
    <div className={styles.spotlight}>
      <img src={media?.Poster} alt='spotlight' className={styles.spotlight__image} />
      <div className={styles.spotlight__details}>
        <div className={styles.title}>
          {media?.Title} ({media?.Year})
        </div>
        <div className={styles.synopsis}>{media?.Plot}</div>
        <div className={styles.buttonRow}>
          <Button label='Play' filled Icon={Play} />
          {media && (
            <Button label='More Info' Icon={Info} onClick={() => onClick(media)} />
          )}
        </div>
      </div>
    </div>
  );
}
