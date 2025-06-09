class SlackNeighborhood
  def self.find_by_id(id)
    # Get the neighborhood data from the cache or fetch it from the API
    key = "slack_neighborhood_#{id}"

    specific_neighborhood = Rails.cache.fetch(key, expires_in: 10.days) do
      neighborhood_data = Rails.cache.fetch("slack_neighborhood_list", expires_in: 3.days) do
        response = HTTP.get("https://skksk8sos4g4c0kw4cw0ks80.a.selfhosted.hackclub.com/personal")
        JSON.parse(response.body)
      end

      neighborhood_data.find { |neighborhood| neighborhood["channelManagers"].include?(id) }
    end

    Rails.cache.delete(key) if specific_neighborhood.nil?

    specific_neighborhood
  rescue StandardError => e
    Rails.logger.error("Error in SlackNeighborhood.find_by_id: #{e.message}")
    nil
  end
end
