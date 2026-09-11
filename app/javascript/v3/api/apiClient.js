import axios from 'axios';

const { apiHost = '' } = window.woodeskConfig || {};
const wootAPI = axios.create({ baseURL: `${apiHost}/` });

export default wootAPI;
