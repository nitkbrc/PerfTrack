module AdminHelper
  def admin_label_classes
    "block text-sm font-medium text-slate-700"
  end

  def admin_input_classes
    "mt-1 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm " \
    "placeholder:text-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/40"
  end

  def admin_primary_button_classes
    "cursor-pointer rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " \
    "transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
  end

  def admin_link_classes
    "text-sm font-medium text-indigo-600 hover:text-indigo-500"
  end

  def admin_delete_classes
    "cursor-pointer text-sm font-medium text-red-600 hover:text-red-500"
  end
end
