require "open3"

class GitRemote
  def self.check_remote_exists(repo_url)
    # only run check if git is installed and in path
    return true unless system("git --version")

    # Only allow safe protocols
    return false unless repo_url.match?(/\A(https?|git|ssh):\/\//)

    safe_repo_url = URI.parse(repo_url).to_s.gsub(" ", "").gsub("'", "") rescue (return false)
    
    Open3.capture2e(
      {"GIT_CURL_TIMEOUT"=>"15","GIT_HTTP_LOW_SPEED_LIMIT"=>"1000","GIT_HTTP_LOW_SPEED_TIME"=>"15","GIT_HTTP_MAX_REQUESTS"=>"5"},
      "git","ls-remote","--",safe_repo_url
    ).last.success?
  end
end
