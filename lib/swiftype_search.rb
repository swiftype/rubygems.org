module SwiftypeSearch
  extend ActiveSupport::Concern

  included do
    after_commit :update_swiftype_index
  end

  def update_swiftype_index
    Delayed::Job.enqueue UpdateRubygemSwiftype.new(id), :priority => PRIORITIES[:swiftype_index]
  end

  def to_st_hash
    latest_version = versions.latest.first
    url = Rails.application.routes.url_helpers.rubygem_url(self, host: HOST)
    {
      :external_id => id,
      :fields => [
        {:name => 'name', :value => name, :type => 'string'},
        {:name => 'authors', :value => latest_version.authors, :type => 'string'},
        {:name => 'summary', :value => latest_version.summary, :type => 'string'},
        {:name => 'version', :value => latest_version.number, :type => 'string'},
        {:name => 'downloads', :value => downloads, :type => 'integer'},
        {:name => 'url', :value => url, :type => 'enum'},
        {:name => 'description', :value => latest_version.description, :type => 'text'}
      ]
    }
  end

  def self.search(query)
    client = Swiftype::Client.new
    res = client.search("rubygems", query, document_types: ["rubygem"], search_fields: ["name^3","author","summary","description"])
    ids = res.records["rubygem"].map { |a| a["external_id"] }
    Rubygem.where(id: ids).
      includes(:versions).
      by_downloads
  end
end
