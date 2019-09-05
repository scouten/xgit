defmodule Xgit.Core.Tree do
  @moduledoc ~S"""
  Represents a git `tree` object in memory.
  """
  alias Xgit.Core.FileMode
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  This struct describes a single `tree` object so it can be manipulated in memory.

  ## Struct Members

  * `:entries`: list of `Tree.Entry` structs, which must be sorted by name
  """
  @type t :: %__MODULE__{entries: [__MODULE__.Entry.t()]}

  @enforce_keys [:entries]
  defstruct [:entries]

  defmodule Entry do
    @moduledoc ~S"""
    A single file in a `tree` structure.
    """

    use Xgit.Core.FileMode

    alias Xgit.Core.FileMode
    alias Xgit.Core.FilePath
    alias Xgit.Core.ObjectId
    alias Xgit.Util.Comparison

    import Xgit.Util.ForceCoverage

    @typedoc ~S"""
    A single file in a tree structure.

    ## Struct Members

    * `name`: (`FilePath.t`) entry path name, relative to top-level directory (without leading slash)
    * `object_id`: (`ObjectId.t`) SHA-1 for the represented object
    * `mode`: (`FileMode.t`)
    """
    @type t :: %__MODULE__{
            name: FilePath.t(),
            object_id: ObjectId.t(),
            mode: FileMode.t()
          }

    @enforce_keys [:name, :object_id, :mode]
    defstruct [:name, :object_id, :mode]

    @doc ~S"""
    Return `true` if this entry struct describes a valid tree entry.
    """
    @spec valid?(entry :: any) :: boolean
    def valid?(entry)

    def valid?(
          %__MODULE__{
            name: name,
            object_id: object_id,
            mode: mode
          } = _entry
        )
        when is_list(name) and is_binary(object_id) and is_file_mode(mode) do
      FilePath.check_path_segment(name) == :ok && ObjectId.valid?(object_id) &&
        object_id != ObjectId.zero()
    end

    def valid?(_), do: cover(false)

    @doc ~S"""
    Compare two entries according to git file name sorting rules.

    ## Return Value

    * `:lt` if `entry1` sorts before `entry2`.
    * `:eq` if they are the same.
    * `:gt` if `entry1` sorts after `entry2`.
    """
    @spec compare(entry1 :: t | nil, entry2 :: t) :: Comparison.result()
    def compare(entry1, entry2)

    def compare(nil, _entry2), do: cover(:lt)

    def compare(%{name: name1} = _entry1, %{name: name2} = _entry2) do
      cond do
        name1 < name2 -> cover :lt
        name2 < name1 -> cover :gt
        true -> cover :eq
      end
    end
  end

  @doc ~S"""
  Return `true` if the value is a tree struct that is valid.

  All of the following must be true for this to occur:
  * The value is a `Tree` struct.
  * The entries are properly sorted.
  * All entries are valid, as determined by `Xgit.Core.Tree.Entry.valid?/1`.
  """
  @spec valid?(tree :: any) :: boolean
  def valid?(tree)

  def valid?(%__MODULE__{entries: entries}) when is_list(entries) do
    Enum.all?(entries, &Entry.valid?/1) && entries_sorted?([nil | entries])
  end

  def valid?(_), do: cover(false)

  defp entries_sorted?([entry1, entry2 | tail]),
    do: Entry.compare(entry1, entry2) == :lt && entries_sorted?([entry2 | tail])

  defp entries_sorted?([_]), do: cover(true)

  @doc ~S"""
  Renders this tree structure into a corresponding `Xgit.Core.Object`.
  """
  @spec to_object(tree :: t) :: Object.t()
  def to_object(tree)

  def to_object(%__MODULE__{entries: entries} = _tree) do
    rendered_entries =
      entries
      |> Enum.map(&entry_to_iodata/1)
      |> IO.iodata_to_binary()
      |> :binary.bin_to_list()

    %Object{
      type: :tree,
      content: rendered_entries,
      size: Enum.count(rendered_entries),
      id: ObjectId.calculate_id(rendered_entries, :tree)
    }
  end

  defp entry_to_iodata(%__MODULE__.Entry{name: name, object_id: object_id, mode: mode}),
    do: cover([FileMode.to_short_octal(mode), ?\s, name, 0, ObjectId.to_binary_iodata(object_id)])
end
