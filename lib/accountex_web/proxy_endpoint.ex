defmodule AccountexWeb.ProxyEndpoint do
  use Beacon.ProxyEndpoint,
    otp_app: :accountex,
    session_options: Application.compile_env!(:accountex, :session_options),
    fallback: AccountexWeb.Endpoint
end
