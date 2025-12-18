defmodule VolaBridge.Certificate do
  @moduledoc """
      Helper funcion for certificates used in Vola Bridge contracts.
  """
  alias VolaBridge.Types.FingerprintDatum
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Data
  alias Sutra.Cardano.Transaction.Output
  alias VolaBridge.Types.CertificateDatum

  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Crypto.Key, as: SutraCrypto

  def calc_total_bridge_inputs(
        [%Input{} | _] = bridge_inputs,
        [%CertificateDatum{} | _] = certificates,
        vola_token_policy_id,
        vola_token_asset_name
      ) do
    total_amt_to_redeem = Enum.reduce(certificates, 0, &(&1.amount + &2))

    sort_inputs_by_vola_token(bridge_inputs, vola_token_policy_id, vola_token_asset_name)
    |> calc_inputs_to_cover_amount(
      total_amt_to_redeem,
      vola_token_policy_id,
      vola_token_asset_name
    )
  end

  defp sort_inputs_by_vola_token(inputs, vola_token_policy_id, vola_token_asset_name) do
    Enum.sort_by(
      inputs,
      fn %Input{output: %Output{value: assets}} ->
        Map.get(assets, vola_token_policy_id, %{})
        |> Map.get(vola_token_asset_name, 0)
      end,
      :desc
    )
  end

  defp calc_inputs_to_cover_amount(
         inputs,
         required_amount,
         vola_token_policy_id,
         vola_token_asset_name
       ) do
    Enum.reduce_while(inputs, {required_amount, []}, fn %Input{output: %Output{value: assets}} =
                                                          curr_input,
                                                        {amount_to_fill, used_inputs} ->
      vola_token_amount =
        Map.get(assets, vola_token_policy_id, %{}) |> Map.get(vola_token_asset_name, 0)

      new_to_fill =
        amount_to_fill - vola_token_amount

      new_used_inputs = [curr_input | used_inputs]

      if new_to_fill <= 0,
        do: {:halt, {new_to_fill, new_used_inputs}},
        else: {:cont, {new_to_fill, new_used_inputs}}
    end)
  end

  def generate_fingerprint(certificateDatumHashes, signer) do
    Enum.reduce_while(certificateDatumHashes, %{}, fn certDtmHash, acc ->
      case SutraCrypto.from_bech32(signer) do
        {:ok, privkey} ->
          pubkey = SutraCrypto.public_key(privkey)

          # Ensure we sign the raw binary of the hash, not the hex string
          sig = SutraCrypto.sign(privkey, Base.decode16!(certDtmHash, case: :mixed))
          {:cont, Map.put(acc, certDtmHash, {pubkey, sig})}

        _ ->
          {:halt, %{}}
      end
    end)
  end

  def merge_fingerprints(fingerprint_lists) do
    Enum.reduce(fingerprint_lists, %{}, fn fps, acc ->
      init_or_add_fingerprint(acc, fps)
    end)
  end

  defp init_or_add_fingerprint(prev, curr_val) when is_map(prev) and is_map(curr_val) do
    Enum.reduce(curr_val, prev, fn {k, v}, acc ->
      case Map.get(acc, k) do
        nil -> Map.put(acc, k, [v])
        existing_val -> Map.put(acc, k, existing_val ++ [v])
      end
    end)
  end

  def prepare_withdraw_signatures(certificates, fingerprints) do
    Enum.map(certificates, fn %CertificateDatum{} = cert_dtm ->
      cert_dtm_hash = Data.encode(cert_dtm) |> Datum.calculate_datum_hash()

      fingerprint_datum_hash =
        fingerprints[cert_dtm_hash]
        |> FingerprintDatum.to_plutus()
        |> Data.encode()
        |> Datum.calculate_datum_hash()

      {Base.decode16!(cert_dtm_hash, case: :mixed),
       Base.decode16!(fingerprint_datum_hash, case: :mixed)}
    end)
  end

  def prepare_fingerprint_datums(fingerprints) do
    Enum.map(fingerprints, &elem(&1, 1))
  end
end
