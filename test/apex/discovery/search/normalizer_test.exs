defmodule Apex.Discovery.Search.NormalizerTest do
  use ExUnit.Case, async: true

  alias Apex.Discovery.Search.Normalizer

  test "nil normalises to an empty string" do
    assert Normalizer.normalize(nil) == ""
  end

  test "folds case and collapses whitespace" do
    assert Normalizer.normalize("  Gulf   TRADING ") == "gulf trading"
    assert Normalizer.normalize("INV-123") == "inv-123"
  end

  test "folds Latin accents so accented and plain forms match" do
    assert Normalizer.normalize("Crédit") == Normalizer.normalize("Credit")
    assert Normalizer.normalize("São Paulo") == "sao paulo"
  end

  test "folds Arabic diacritics (tashkil) so vocalised and plain forms match" do
    # "مُحَمَّد" (with harakat) folds to the same terms as "محمد" (without)
    assert Normalizer.normalize("مُحَمَّد") == Normalizer.normalize("محمد")
  end

  test "normalisation is symmetric for indexed terms and queries" do
    indexed = Normalizer.normalize("Gulf Trading")
    query = Normalizer.normalize("gulf trading")
    assert indexed == query
  end
end
