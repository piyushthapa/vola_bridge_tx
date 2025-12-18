defmodule VolaBridge.Tx.RedeemBridgeTxTest do
  @moduledoc false

  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.TxBuilder
  alias VolaBridge.Tx.Bridge
  alias Sutra.Provider

  use Sutra.PrivnetTest

  import TxSupport, only: [place_token_to_bridge: 1]

  describe "Redeem bridge with multiple certificate" do
    test "Redeem token must goto valid receipients" do
      [input1] = Enum.map([500], &place_token_to_bridge/1)

      receipient1 = {random_address(), 160}
      # receipient2 = {random_address(), 300}

      [settings_utxo] = Provider.utxos_at_refs([TxSupport.fetch_settings_ref()])

      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        [user_utxo | _] =
          Provider.utxos_at([addr])
          |> Enum.filter(fn utxo ->
            Asset.lovelace_of(utxo.output.value) > 10_000_000
          end)

        certificates =
          RedeemBridgeSupport.prepare_certificate(user_utxo.output_reference, [
            receipient1
          ])

        fingerprints = RedeemBridgeSupport.prepare_fingerprints(certificates)

        assert %TxBuilder{} =
                 builder =
                 Bridge.withdraw_from_bridge(
                   settings_utxo,
                   [input1],
                   certificates,
                   [user_utxo],
                   fingerprints,
                   TxSupport.vola_token_policy_id(),
                   TxSupport.vola_token_asset_name(),
                   addr
                 )

        assert {:ok, tx} = TxBuilder.build_tx(builder, wallet_address: addr)

        tx_id =
          TxBuilder.sign_tx(tx, [skey])
          |> TxBuilder.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
