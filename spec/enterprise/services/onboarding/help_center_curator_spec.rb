require 'rails_helper'

RSpec.describe Onboarding::HelpCenterCurator do
  let(:account) { create(:account, custom_attributes: { 'website' => 'woodesk.com' }) }
  let(:links) do
    [
      { 'url' => 'https://woodesk.com/docs/a', 'title' => 'A' },
      { url: 'https://woodesk.com/docs/b', title: 'B' },
      'https://woodesk.com/docs/c'
    ]
  end
  let(:llm_response) do
    {
      message: {
        categories: [{ name: 'Docs', description: 'Docs' }],
        articles: [
          { title: 'A', urls: ['https://woodesk.com/docs/a'], category_name: 'Docs' },
          { title: 'B', urls: ['https://woodesk.com/docs/b'], category_name: 'Docs' },
          { title: 'C', urls: ['https://woodesk.com/docs/c'], category_name: 'Docs' }
        ]
      }
    }
  end

  before do
    firecrawl_client = instance_double(Firecrawl::Client, map: instance_double(Firecrawl::Models::MapData, links: links))
    llm_service = instance_double(Captain::Llm::HelpCenterCurationService, perform: llm_response)

    allow(Firecrawl::Configuration).to receive(:configured?).and_return(true)
    allow(Firecrawl::Configuration).to receive(:client).and_return(firecrawl_client)
    allow(Captain::Llm::HelpCenterCurationService).to receive(:new)
      .with(account: account, links: links)
      .and_return(llm_service)
  end

  it 'extracts allowed urls from Firecrawl string-keyed link hashes' do
    result = described_class.new(account: account).perform

    expect(result['allowed_urls']).to eq(['https://woodesk.com/docs/a'])
  end
end
