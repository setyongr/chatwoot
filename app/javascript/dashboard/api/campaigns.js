import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  getReport(id) {
    return axios.get(`${this.url}/${id}/report`);
  }
}

export default new CampaignsAPI();
