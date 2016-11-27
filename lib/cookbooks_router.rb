class CookbooksRouter < YARD::Server::Router
  def docs_prefix
    'cookbooks'
  end

  def list_prefix
    'list/cookbooks'
  end

  def search_prefix
    'search/cookbooks'
  end

  def static_prefix
    'static/cookbooks'
  end
end
