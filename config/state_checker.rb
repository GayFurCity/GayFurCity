# frozen_string_literal: true

class StateChecker
  include(Singleton)

  def check!
    %w[SECRET_TOKEN GAYFURCITY_SECRET_TOKEN].any? { |n| ENV[n].present? } || check_secret_token
    %w[SESSION_SECRET_KEY GAYFURCITY_SESSION_SECRET_KEY].any? { |n| ENV[n].present? } || check_session_secret_key
  end

  def secret_token
    %w[SECRET_TOKEN GAYFURCITY_SECRET_TOKEN].map { |n| ENV.fetch(n, nil) }.compact_blank.first || File.read(secret_token_path)
  end

  def session_secret_key
    %w[SESSION_SECRET_KEY GAYFURCITY_SESSION_SECRET_KEY].map { |n| ENV.fetch(n, nil) }.compact_blank.first || File.read(session_secret_key_path)
  end

  private

  def secret_token_path
    File.expand_path("~/.gayfurcity/secret_token")
  end

  def check_secret_token
    unless File.exist?(secret_token_path)
      raise("You must create a file in #{secret_token_path} containing a secret key, or set the SECRET_TOKEN/GAYFURCITY_SECRET_TOKEN environment variable. It should be a string of at least 32 random characters.")
    end

    if File.stat(secret_token_path).world_readable? || File.stat(secret_token_path).world_writable?
      raise("#{secret_token_path} must not be world readable or writable")
    end
  end

  def session_secret_key_path
    File.expand_path("~/.gayfurcity/session_secret_key")
  end

  def check_session_secret_key
    unless File.exist?(session_secret_key_path)
      raise("You must create a file in #{session_secret_key_path} containing a secret key, or set the SESSION_SECRET_KEY/GAYFURCITY_SESSION_SECRET_KEY environment variable. It should be a string of at least 32 random characters.")
    end

    if File.stat(session_secret_key_path).world_readable? || File.stat(session_secret_key_path).world_writable?
      raise("#{session_secret_key_path} must not be world readable or writable")
    end
  end
end
