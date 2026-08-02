# frozen_string_literal: true

class HierarchyStepPolicy < AdminOnlyPolicy
  def move_up?
    update?
  end

  def move_down?
    update?
  end

  def bulk_apply?
    update?
  end
end
