module Teller
  class CredentialVerifier
    def self.verify(identifier:, secret:)
      new(identifier: identifier, secret: secret).call
    end

    def initialize(identifier:, secret:)
      @identifier = identifier.to_s.strip
      @secret = secret.to_s
    end

    def call
      return nil if @identifier.blank? || @secret.blank?
      user = find_user
      return nil unless user
      verified?(user) ? user : nil
    end

    private

    def find_user
      if @identifier.include?("@")
        User.find_by(email_address: @identifier.downcase)
      else
        User.find_by(teller_number: @identifier.upcase)
      end
    end

    def verified?(user)
      if @identifier.include?("@")
        user.authenticate(@secret)
      else
        user.authenticate_pin(@secret)
      end
    end
  end
end
