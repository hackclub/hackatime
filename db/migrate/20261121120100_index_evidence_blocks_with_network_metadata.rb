class IndexEvidenceBlocksWithNetworkMetadata < ActiveRecord::Migration[8.1]
  def change
    add_index :evidence_blocks, :received_at, where: "ip_address IS NOT NULL OR ja4_id IS NOT NULL", name: "index_evidence_blocks_with_network_metadata"
  end
end
