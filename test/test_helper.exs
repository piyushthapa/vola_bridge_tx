alias VolaBridge.BridgeScript.ScriptInfo
# Setting up Application variables for tests
#
init = fn ->
  signers =
    [
      "ed25519_sk1l205xhwy2hd49zggvj9knjwcjzx2huvenj6w7qharx7wvzaf5fgs9swfz6",
      "ed25519_sk1rrlen6f7p3yrha9awmmvx9sz0pmky4rgg9d7c5mesu57ypk684sseeyuku",
      "ed25519_sk1p2gjas5hn5lgv3cz9ypg3hf4vgqsy5ntdmymngxpdx4e6uy7vauqf75yvh"
    ]
    |> Enum.map(fn s ->
      case Sutra.Crypto.Key.from_bech32(s) do
        {:ok, key} -> Sutra.Crypto.Key.pubkey_hash(key)
        {:error, _} -> raise "INVALID SIGNER KEY"
      end
    end)

  Application.put_env(:vola_bridge_tx, :signers, signers)
  Application.put_env(:vola_bridge_tx, :cardano_network, :preprod)

  Sutra.PrivnetTest.set_yaci_provider_env()

  %ScriptInfo{} = TxSupport.mint_vola_token()

  refs = TxSupport.fetch_settings_ref()

  [settings_input] = Sutra.Provider.utxos_at_tx_refs([refs])

  TxSupport.register_bridge_stake_credential(settings_input)
end

init.()

ExUnit.start()
