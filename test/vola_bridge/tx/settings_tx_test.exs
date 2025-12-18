defmodule VolaBridge.Tx.SettingsTxTest do
  @moduledoc false
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.TxBuilder
  alias VolaBridge.Tx.Settings
  alias Sutra.Provider

  use Sutra.PrivnetTest

  describe "Settings Tx Test" do
    test "settings Place Tx" do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        [addr_utxo | _] = Provider.utxos_at([addr])

        {:ok, tx} =
          Settings.create_settings_tx(addr_utxo)
          |> TxBuilder.build_tx(wallet_address: addr)

        txId =
          TxBuilder.sign_tx(tx, [skey])
          |> TxBuilder.submit_tx()

        assert txId == Transaction.tx_id(tx)
      end)
    end
  end
end
