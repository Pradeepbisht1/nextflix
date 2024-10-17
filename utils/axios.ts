import axios, { AxiosInstance } from 'axios';

export default function getInstance(): AxiosInstance {
  return axios.create({
    baseURL: 'http://www.omdbapi.com/',  // OMDb API base URL
  });
}
