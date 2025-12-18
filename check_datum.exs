
# Script to check Datum.calculate_datum_hash
alias Sutra.Cardano.Transaction.Datum
alias Sutra.Data

# Encoded integer 1 is valid CBOR
data = Data.encode(1) |> IO.iodata_to_binary()

begin
  hash = Datum.calculate_datum_hash(data)
  IO.puts "Hash: #{inspect hash}"
  IO.puts "Hash Length (bytes): #{byte_size(hash)}"
  if is_binary(hash) do
     decoded = Base.decode16(hash, case: :mixed)
     case decoded do
       {:ok, bin} -> IO.puts "Decoded Length: #{byte_size(bin)}"
       :error -> IO.puts "Not valid hex"
     end
  end
rescue
  e -> IO.inspect(e, label: "Error")
end
