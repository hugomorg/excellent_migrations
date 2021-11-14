defmodule ExcellentMigrations.Parser do
  def parse(ast) do
    ast
    |> _parse([])
    |> reject_safety_assured()
  end

  defp reject_safety_assured(dangers) do
    if Keyword.get(dangers, :safety_assured) do
      []
    else
      Keyword.delete(dangers, :safety_assured)
    end
  end

  defp _parse(
         {
           :def,
           _,
           [{_name, _, _}, [do: {:__block__, _, body}]]
         },
         acc
       ) do
    parse_body(body, acc)
  end

  defp _parse(
         {
           :def,
           _,
           [{_name, _, _}, [do: body]]
         },
         acc
       ) do
    parse_body(body, acc)
  end

  defp _parse({:@, _, [{:safety_assured, _, [name]}]}, acc) do
    [{:safety_assured, name} | acc]
  end

  defp _parse({_name, _meta, args}, acc) do
    _parse(args, acc)
  end

  defp _parse({:do, tuple}, acc) do
    _parse(tuple, acc)
  end

  defp _parse([head | tail], acc) do
    new_acc = _parse(head, acc)
    _parse(tail, new_acc)
  end

  defp _parse([], acc), do: acc

  defp _parse(_other, acc), do: acc

  defp parse_body(body, acc) do
    dangers = check_for_execute(body) ++ check_for_index_concurrently(body)
    dangers = Enum.reject(dangers, &is_nil/1)
    acc ++ dangers
  end

  defp check_for_execute({:execute, location, _}) do
    [{:execute, Keyword.get(location, :line)}]
  end

  defp check_for_execute([head | tail]) do
    check_for_execute(head) ++ check_for_execute(tail)
  end

  defp check_for_execute(_), do: []

  defp check_for_index_concurrently(
         {:create, location, [{:index, _, [_table, _columns, options]}]}
       ) do
    case Keyword.get(options, :concurrently) do
      true -> []
      _ -> [{:index_not_concurrently, Keyword.get(location, :line)}]
    end
  end

  defp check_for_index_concurrently([head | tail]) do
    check_for_index_concurrently(head) ++ check_for_index_concurrently(tail)
  end

  defp check_for_index_concurrently(_), do: []
end
