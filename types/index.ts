import { Breakpoint } from '../config/breakpoints';

export type Maybe<T> = T | null;

export type Dimension = {
  height: number;
  width: number;
};

export type DimensionDetail = {
  dimension: Dimension;
  breakpoint: Breakpoint;
  isMobile: boolean;
  isTablet: boolean;
  isDesktop: boolean;
};

export type Genre = {
  id: number;
  name: string;
};

export enum MediaType {
  MOVIE = 'movie',
  TV = 'tv'
}

// Updated Media type to match OMDb API structure
export type Media = {
  imdbID: string; // OMDb uses imdbID for unique identification
  title: string; // Maps to OMDb's 'Title'
  overview: string; // Maps to OMDb's 'Plot'
  poster: string; // Maps to OMDb's 'Poster'
  banner: string; // OMDb does not have a specific banner, but you can use 'Poster' as a fallback
  rating: string; // Maps to OMDb's 'imdbRating'
  genre: string[]; // Maps to OMDb's 'Genre' (converted from string to array if needed)
  year: string; // Maps to OMDb's 'Year'
  type: MediaType; // This can be either 'movie' or 'tv' based on OMDb's 'Type'
};

export type ImageType = 'poster' | 'original';

export type Section = {
  heading: string;
  endpoint: string;
  defaultCard?: boolean;
  topList?: boolean;
};

