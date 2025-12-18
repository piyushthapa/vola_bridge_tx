defmodule VolaBridge.BridgeScript do
  @moduledoc """
    Vola Bridge Plutus Scripts
  """

  @settings_asset_name Base.encode16("vola_bridge_settings", case: :lower)
  @vola_bridge_asset_name Base.encode16("vola_bridge", case: :lower)
  @vola_token_asset_name Base.encode16("VOLA", case: :lower)

  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction.OutputReference

  defmodule ScriptInfo do
    defstruct [:script, :script_hash, :asset_name]
  end

  defp fetch_validator(name) do
    File.read!("blueprint-dev.json")
    |> :json.decode()
    |> Map.get("validators")
    |> Enum.find(fn v -> v["title"] == name end)
    |> Map.get("compiledCode")
  end

  def bridge_validator_script(settings_policy_id) do
    bridge_script =
      fetch_validator("bridge.bridge_validator.mint")
      |> Script.apply_params([settings_policy_id, @vola_bridge_asset_name])
      |> Script.new(:plutus_v3)

    %ScriptInfo{
      script: bridge_script,
      script_hash: Script.hash_script(bridge_script),
      asset_name: @vola_bridge_asset_name
    }
  end

  def settings_validator_script(utxo_ref = %OutputReference{}) do
    vola_token_info = %ScriptInfo{} = vola_token_validaor()

    settings_script =
      fetch_validator("settings.settings.mint")
      |> Script.apply_params([
        utxo_ref.transaction_id,
        utxo_ref.output_index,
        @settings_asset_name,
        vola_token_info.script_hash,
        vola_token_info.asset_name
      ])
      |> Script.new(:plutus_v3)

    %ScriptInfo{
      script: settings_script,
      script_hash: Script.hash_script(settings_script),
      asset_name: @settings_asset_name
    }
  end

  def vola_token_validaor() do
    vola_token_policy_script =
      fetch_validator("vola_token.token.mint")
      |> Script.new(:plutus_v3)

    %ScriptInfo{
      script: vola_token_policy_script,
      script_hash: Script.hash_script(vola_token_policy_script),
      asset_name: @vola_token_asset_name
    }
  end
end
