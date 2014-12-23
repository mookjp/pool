require 'spec_helper'

describe server(:pool_proxy) do
  describe http('http://master.pool.dev') do
    it 'returns 200' do
      expect(response.status).to eq(200)
    end
  end

  describe http('http://development.pool.dev') do
    it 'returns 200' do
      expect(response.status).to eq(200)
    end
  end

  describe http('http://master.pool.dev/path/to/something') do
    it 'returns 200' do
      expect(response.status).to eq(200)
    end
  end
end
