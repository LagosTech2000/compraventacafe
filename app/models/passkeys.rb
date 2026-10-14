# The WebAuthn relying party for this request: the site the passkeys belong
# to. Its id is the host the browser is on (localhost in development, the
# Render domain in production), so a passkey only works on the site where it
# was registered; the browser enforces it too.
module Passkeys
  def self.relying_party(request)
    WebAuthn::RelyingParty.new(id: request.host, allowed_origins: [ request.base_url ],
                               name: SiteSetting.current.business_name)
  end
end
