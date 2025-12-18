defmodule RedeemBridgeSupport do
  @moduledoc false

  @signers [
    "ed25519_sk1l205xhwy2hd49zggvj9knjwcjzx2huvenj6w7qharx7wvzaf5fgs9swfz6",
    "ed25519_sk1rrlen6f7p3yrha9awmmvx9sz0pmky4rgg9d7c5mesu57ypk684sseeyuku",
    "ed25519_sk1p2gjas5hn5lgv3cz9ypg3hf4vgqsy5ntdmymngxpdx4e6uy7vauqf75yvh"
  ]

  alias Sutra.Cardano.Transaction.Datum
  alias VolaBridge.Certificate
  alias VolaBridge.Types.CertificateDatum
  alias Sutra.Cardano.Transaction.OutputReference

  def prepare_certificate(
        %OutputReference{} = utxo,
        recipients,
        vola_chain_tx_id \\ "",
        invalid_after \\ :os.system_time(:millisecond) + 15 * 60 * 1000
      ) do
    Enum.map(recipients, fn {addr, amount} ->
      %CertificateDatum{
        invalid_after: invalid_after,
        utxo: utxo,
        receiver_address: addr,
        amount: amount,
        vola_chain_tx_id: vola_chain_tx_id
      }
    end)
  end

  def prepare_fingerprints(certificates) do
    Enum.map(@signers, fn skey ->
      Enum.map(certificates, fn %CertificateDatum{} = cert ->
        Sutra.Data.encode(cert) |> Datum.calculate_datum_hash()
      end)
      |> Certificate.generate_fingerprint(skey)
    end)
    |> Certificate.merge_fingerprints()
  end
end
