defmodule VolaBridge.Tx.BridgeTxTest do
  @moduledoc false

  alias VolaBridge.BridgeScript.ScriptInfo
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.TxBuilder
  alias Sutra.Provider
  alias VolaBridge.Tx.Bridge
  alias VolaBridge.Types.BridgeDatum

  use Sutra.PrivnetTest

  defp bridge_datum(amount \\ 500) do
    %BridgeDatum{
      amount: amount,
      receiver_address: "",
      created_at: :os.system_time(:second)
    }
  end

  describe "Lock fund to Bridge Test" do
    test "lock fund to Bridge" do
      [settings_utxo] = [TxSupport.fetch_settings_ref()] |> Provider.utxos_at_tx_refs()

      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        vola_token_info = %ScriptInfo{} = TxSupport.mint_vola_token(addr, skey)

        {:ok, tx} =
          Bridge.place_bridge(
            settings_utxo,
            bridge_datum(),
            vola_token_info.script_hash,
            vola_token_info.asset_name
          )
          |> TxBuilder.build_tx(wallet_address: addr)

        tx_id =
          TxBuilder.sign_tx(tx, [skey])
          |> TxBuilder.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
