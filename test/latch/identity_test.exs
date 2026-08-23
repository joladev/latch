defmodule Latch.IdentityTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Latch.DNS
  alias Latch.HTTP
  alias Latch.Identity

  @handle "jola.dev"
  @did "did:plc:bvraa6gajy4tfr3eh2sisdkr"
  @pds_endpoint "https://pds.cove.town"

  describe "resolve_handle/2" do
    test "resolve DNS" do
      config = make_config()
      did_document = make_did_document(@did, @handle, @pds_endpoint)

      expect(DNS, :lookup_txt, fn record ->
        assert ["_atproto", "jola", "dev"] = String.split(record, ".")
        ["did=#{@did}"]
      end)

      reject(&HTTP.get_text/2)

      expect(HTTP, :get_json, fn _pool, url ->
        assert url == "https://plc.directory/#{@did}"
        {:ok, did_document}
      end)

      assert {:ok, %{did: @did, handle: @handle, pds_endpoint: @pds_endpoint}} =
               Identity.resolve_handle(config, @handle)
    end

    test "resolve .well-known" do
      config = make_config()
      did_document = make_did_document(@did, @handle, @pds_endpoint)

      expect(DNS, :lookup_txt, fn _record ->
        []
      end)

      expect(HTTP, :get_text, fn _pool, url ->
        assert url == "https://#{@handle}/.well-known/atproto-did"
        {:ok, @did}
      end)

      expect(HTTP, :get_json, fn _pool, url ->
        assert url == "https://plc.directory/#{@did}"
        {:ok, did_document}
      end)

      assert {:ok, %{did: @did, handle: @handle, pds_endpoint: @pds_endpoint}} =
               Identity.resolve_handle(config, @handle)
    end

    test "ambiguous DNS" do
      config = make_config()

      expect(DNS, :lookup_txt, fn _record ->
        ["did=unexpected", "did=stuff"]
      end)

      assert {:error, %Latch.Error.HandleNotFound{reason: :ambiguous_dns}} =
               Identity.resolve_handle(config, @handle)
    end

    test "no resolution" do
      config = make_config()

      expect(DNS, :lookup_txt, fn _record ->
        []
      end)

      expect(HTTP, :get_text, fn _pool, _url ->
        {:error, %Latch.Error.InvalidResponse{reason: {:http_status, 404}}}
      end)

      reject(&HTTP.get_json/2)

      assert {:error, %Latch.Error.HandleNotFound{reason: :handle_not_found}} =
               Identity.resolve_handle(config, @handle)
    end

    test "web did dns" do
      config = make_config()
      did = "did:web:jola.dev"
      did_document = make_did_document(did, @handle, @pds_endpoint)

      expect(DNS, :lookup_txt, fn record ->
        assert ["_atproto", "jola", "dev"] = String.split(record, ".")
        ["did=#{did}"]
      end)

      reject(&HTTP.get_text/2)

      expect(HTTP, :get_json, fn _pool, url ->
        assert url == "https://jola.dev/.well-known/did.json"
        {:ok, did_document}
      end)

      assert {:ok, %{did: ^did, handle: @handle, pds_endpoint: @pds_endpoint}} =
               Identity.resolve_handle(config, @handle)
    end

    test "web did .well-known" do
      config = make_config()
      did = "did:web:#{@handle}"
      did_document = make_did_document(did, @handle, @pds_endpoint)

      expect(DNS, :lookup_txt, fn _record ->
        []
      end)

      expect(HTTP, :get_text, fn _pool, url ->
        assert url == "https://#{@handle}/.well-known/atproto-did"
        {:ok, did}
      end)

      expect(HTTP, :get_json, fn _pool, url ->
        assert url == "https://#{@handle}/.well-known/did.json"
        {:ok, did_document}
      end)

      assert {:ok, %{did: ^did, handle: @handle, pds_endpoint: @pds_endpoint}} =
               Identity.resolve_handle(config, @handle)
    end

    test "web did failure" do
      config = make_config()
      did = "did:web:#{@handle}"

      expect(DNS, :lookup_txt, fn _record ->
        ["did=#{did}"]
      end)

      expect(HTTP, :get_json, fn _pool, _url ->
        {:error, %Latch.Error.InvalidResponse{reason: {:http_status, 404}}}
      end)

      assert {:error, %Latch.Error.InvalidResponse{reason: {:http_status, 404}}} =
               Identity.resolve_handle(config, @handle)
    end

    test "plc override" do
      plc_override = "http://localhost:2582"
      config = make_config(plc_directory: plc_override)
      did_document = make_did_document(@did, @handle, @pds_endpoint)

      expect(DNS, :lookup_txt, fn record ->
        assert ["_atproto", "jola", "dev"] = String.split(record, ".")
        ["did=#{@did}"]
      end)

      reject(&HTTP.get_text/2)

      expect(HTTP, :get_json, fn _pool, url ->
        assert url == "#{plc_override}/#{@did}"
        {:ok, did_document}
      end)

      assert {:ok, %{did: @did, handle: @handle, pds_endpoint: @pds_endpoint}} =
               Identity.resolve_handle(config, @handle)
    end
  end

  defp make_config(overrides \\ []) do
    defaults = [
      store: Latch.TestStore,
      client_id_path: "/oauth-client-metadata.json",
      redirect_uri_path: "/oauth/callback",
      scope: "atproto",
      signing_key: Jason.decode!(Jason.encode!(Latch.DPoP.generate_key())),
      name: :"flow_test_#{inspect(self())}",
      mode: :confidential,
      base_url_fun: fn -> "https://client.example.com" end
    ]

    attrs = Keyword.merge(defaults, overrides)
    struct!(Latch.Config, attrs)
  end

  def make_did_document(did, handle, pds) do
    %{
      "@context" => [
        "https://www.w3.org/ns/did/v1",
        "https://w3id.org/security/multikey/v1",
        "https://w3id.org/security/suites/secp256k1-2019/v1"
      ],
      "id" => did,
      "alsoKnownAs" => ["at://#{handle}"],
      "verificationMethod" => [
        %{
          "id" => "#{did}#atproto",
          "type" => "Multikey",
          "controller" => did,
          "publicKeyMultibase" => "zQ3shmuZAiJ7LF1spHm2hNHwEmrQ9yKcXTo6XtsV8ii7YZYq7"
        }
      ],
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => pds
        }
      ]
    }
  end
end
