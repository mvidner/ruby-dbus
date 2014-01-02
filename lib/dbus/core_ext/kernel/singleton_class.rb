# copied from activesupport/core_ext from Rails, MIT license
# https://github.com/rails/rails/tree/5aa869861c192daceafe3a3ee50eb93f5a2b7bd2/activesupport/lib/active_support/core_ext
module Kernel
  # class_eval on an object acts like singleton_class.class_eval.
  def class_eval(*args, &block)
    singleton_class.class_eval(*args, &block)
  end
end
