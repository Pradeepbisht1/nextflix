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
  const { setModalData, setIsModal } = useContext(ModalContext);

  const onClick = (data: Media) => {
    setModalData(data);
    setIsModal(true);
  };

  const getMedia = async () => {
    try {
      const randomTitles = ['Inception', 'The Matrix', 'Interstellar', 'The Dark Knight', 'Fight Club']; // Add more titles as needed
      const random = Math.floor(Math.random() * randomTitles.length);
      const selectedTitle = randomTitles[random];

      const apiKey = '29efbf52'; // Replace with your actual OMDb API key
      const response = await axios.get(`http://www.omdbapi.com/?t=${encodeURIComponent(selectedTitle)}&apikey=${apiKey}`);
      
      if (response.data && response.data.Response === 'True') {
        setMedia(response.data);
      }
    } catch (error) {
      console.error('Error fetching media:', error);
    }
  };

  useEffect(() => {
    getMedia();
  }, []);

  return (
    <div className={styles.spotlight}>
      {media?.Poster && (
        <img src={media.Poster} alt='spotlight' className={styles.spotlight__image} />
      )}
      <div className={styles.spotlight__details}>
        <div className={styles.title}>{media?.Title} ({media?.Year})</div>
        <div className={styles.synopsis}>{media?.Plot}</div>
        <div className={styles.buttonRow}>
          <Button label='Play' filled Icon={Play} />
          {media && <Button label='More Info' Icon={Info} onClick={() => onClick(media)} />}
        </div>
      </div>
    </div>
  );
}
