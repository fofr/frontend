class TransactionPresenter

  def initialize(transaction)
    @transaction = transaction
  end

  def multiple_more_information_sections?
    num_sections = [:before_you_start?, :what_you_need_to_know?, :other_ways_to_apply?].count {|s| self.send(s) }
    num_sections > 1
  end

  def before_you_start?
    @transaction.more_information.present?
  end

  def what_you_need_to_know?
    @transaction.minutes_to_complete.present? || @transaction.expectations.any?
  end

  def other_ways_to_apply?
    @transaction.alternate_methods.present?
  end
end