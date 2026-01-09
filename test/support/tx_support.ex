defmodule TxSupport do
  alias Config.Provider
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Cardano.Transaction
  alias VolaBridge.Tx.Bridge
  alias VolaBridge.Types.BridgeDatum
  alias Sutra.PrivnetTest
  alias Sutra.Provider
  alias VolaBridge.BridgeScript
  alias VolaBridge.BridgeScript.ScriptInfo
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Transaction.TxBuilder

  @vola_default_token_holder Address.from_bech32(
                               "addr_test1vqjtjdd8460ec68wws4nrpsth73jf9j7gmmyevepjk5nz7g0gr9uf"
                             )

  @default_vola_token_holder_skey "ed25519_sk15d77kh0paep2cdxqwgg7en8w80z67gwrq6zpk7q9zyuqj26uqgsqchtwma"

  @signer_keys [
    "ed25519_sk1l205xhwy2hd49zggvj9knjwcjzx2huvenj6w7qharx7wvzaf5fgs9swfz6",
    "ed25519_sk1rrlen6f7p3yrha9awmmvx9sz0pmky4rgg9d7c5mesu57ypk684sseeyuku",
    "ed25519_sk1p2gjas5hn5lgv3cz9ypg3hf4vgqsy5ntdmymngxpdx4e6uy7vauqf75yvh"
  ]

  @vola_token_script_info BridgeScript.vola_token_validaor()

  @vola_token_policy_id @vola_token_script_info.script_hash
  @vola_token_asset_name @vola_token_script_info.asset_name

  def vola_token_policy_id, do: @vola_token_policy_id
  def vola_token_asset_name, do: @vola_token_asset_name

  def signers, do: @signer_keys

  def mint_vola_token(
        receiver_addr = %Address{} \\ @vola_default_token_holder,
        receiever_skey \\ @default_vola_token_holder_skey,
        amount \\ 1_000_000
      ) do
    addr_utxos = Provider.utxos_at_addresses([receiver_addr])

    if addr_utxos == [] do
      PrivnetTest.load_ada(receiver_addr, [5, 100])
    end

    vola_token_script_info =
      %ScriptInfo{} = BridgeScript.vola_token_validaor()

    TxBuilder.new_tx()
    |> TxBuilder.mint_asset(
      vola_token_script_info.script_hash,
      %{vola_token_script_info.asset_name => amount},
      vola_token_script_info.script,
      Sutra.Data.void()
    )
    |> TxBuilder.add_output(
      receiver_addr,
      %{vola_token_script_info.script_hash => %{vola_token_script_info.asset_name => amount}}
    )
    |> TxBuilder.build_tx!(wallet_address: receiver_addr)
    |> TxBuilder.sign_tx([receiever_skey])
    |> TxBuilder.submit_tx()
    |> PrivnetTest.await_tx()

    vola_token_script_info
  end

  def register_bridge_stake_credential(settings_input \\ nil) do
    settings_input =
      settings_input ||
        [TxSupport.fetch_settings_ref()] |> Provider.utxos_at_tx_refs() |> hd()

    VolaBridge.Tx.Bridge.register_stake_credential(
      settings_input,
      "pool1wvqhvyrgwch4jq9aa84hc8q4kzvyq2z3xr6mpafkqmx9wce39zy"
    )
    |> TxBuilder.build_tx!(wallet_address: @vola_default_token_holder)
    |> TxBuilder.sign_tx([@default_vola_token_holder_skey])
    |> TxBuilder.submit_tx()
  end

  def fetch_settings_ref() do
    case Application.get_env(:vola_bridge_test_settings_ref, :settings_ref_input) do
      nil ->
        PrivnetTest.with_new_wallet(fn %{address: addr, signing_key: skey} ->
          [addr_utxo | _] = Provider.utxos_at_addresses([addr])

          tx_id =
            VolaBridge.Tx.Settings.create_settings_tx(addr_utxo)
            |> TxBuilder.build_tx!(wallet_address: addr)
            |> TxBuilder.sign_tx([skey])
            |> TxBuilder.submit_tx()

          PrivnetTest.await_tx(tx_id)
          Application.put_env(:vola_bridge_test_settings_ref, :settings_ref_input, "#{tx_id}#0")
          "#{tx_id}#0"
        end)

      ref_input_info ->
        ref_input_info
    end
  end

  def default_vola_token_holder_skey, do: @default_vola_token_holder_skey

  def default_vola_token_holder_addr, do: @vola_default_token_holder

  def place_token_to_bridge(amount) do
    [settings_utxo] = [TxSupport.fetch_settings_ref()] |> Provider.utxos_at_tx_refs()

    datum = %BridgeDatum{
      amount: amount,
      receiver_address: "",
      created_at: :os.system_time(:second)
    }

    PrivnetTest.with_new_wallet(fn %{signing_key: skey, address: addr} ->
      %Transaction{
        tx_body: %TxBody{}
      } =
        tx =
        settings_utxo
        |> Bridge.place_bridge(datum, @vola_token_policy_id, @vola_token_asset_name)
        |> TxBuilder.build_tx!(wallet_address: [addr, @vola_default_token_holder])

      tx_id =
        tx
        |> TxBuilder.sign_tx([skey, @default_vola_token_holder_skey])
        |> TxBuilder.submit_tx()

      PrivnetTest.await_tx(tx_id)

      [bridge_input] = Provider.utxos_at_tx_refs(["#{tx_id}#0"])

      bridge_input
    end)
  end
end
