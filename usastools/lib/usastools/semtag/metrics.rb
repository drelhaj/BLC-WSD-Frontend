
module USASTools::SemTag

  module Metrics
    

    # Compare two lists of tags
    #
    # This is a mangled form of the Demerau-Levenshtein distance,
    # with support for non-unit costs coming from self.edit_distance_tag
    #
    # Outputs between 0 and 1 where a and b are arrays of tags.
    def self.edit_distance_tags(a, b, transposition_threshold = 0)
      # Many thanks to http://davefancher.com/tag/damerau-levenshtein-distance/
      # whence this algorithm.
     
      # Convert to an array of tags if not already one
      a = a.tags if a.is_a?(CompoundSemTag)
      b = b.tags if b.is_a?(CompoundSemTag)

      return 0 if a.length == 0 && b.length == 0

      # 2D array axb
      mx = []
      (a.length + 1).times { mx << ([0] * (b.length + 1)) }

      (a.length + 1).times do |i|
        (b.length + 1).times do |j|


          if i == 0
            mx[i][j] = j
          elsif j == 0
            mx[i][j] = i
          else
            # Assign current chars for easier use
            ta, tb = a[i - 1], b[j - 1]

            cost = self.edit_distance_tag(ta, tb)

            # Get cost of operations from matrix
            ops = []
            ops << mx[i][j - 1]      + 1      # Insertion
            ops << mx[i - 1][j]      + 1      # Deletion
            ops << mx[i - 1][j - 1]  + cost   # Substitution

            # And find minimum
            distance      = ops.min

            # Check for transposition using fuzzy boolean check on equality
            if(i > 1 && j > 1 && 
              self.edit_distance_tag(ta, b[j - 2]) <= transposition_threshold && 
              self.edit_distance_tag(a[i - 2], tb) <= transposition_threshold )

              mx[i][j] = [distance, mx[i - 2][j - 2] + cost].min
            else
              mx[i][j] = distance
            end
          end

        end
      end

      # Normalise by longest string length and return
      return mx[a.length][b.length].to_f / [a.length, b.length].max
    end


    # Compare two single SemTag objects
    #
    # Normalised between 0 and 1.
    def self.edit_distance_tag(ta, tb, transposition_threshold = 0)

      # If either is a compound tag, compare them as lists
      if ta.is_a?(CompoundSemTag) || tb.is_a?(CompoundSemTag)
        # Convert both to arrays
        ta = ta.is_a?(CompoundSemTag) ? ta.tags : [ta]
        tb = tb.is_a?(CompoundSemTag) ? tb.tags : [tb]

        # return diff
        return self.edit_distance_tags(ta, tb, transposition_threshold)
      end

      # If both are normal tags, return normalised tag distance
      return (category_distance_tag(ta, tb) + 
              modifier_distance_tag(ta, tb) +
              affinity_distance_tag(ta, tb)) / 3.0
    end


    # Compute distance of category ONLY between two SemTags
    #
    # Ranges from 0 to 1
    def self.category_distance_tag(ta, tb)
      # Difference in stack length
      count = (ta.stack.length - tb.stack.length).abs

      # Plus one for each non-shared stack item
      # TODO: rework algorithm to do arithmetic instead of unnecessary
      # loops.
      difference = false
      [ta.stack.length, tb.stack.length].min.times do |i|
        difference = true if ta.stack[i] != tb.stack[i]
        count += 1 if difference
      end

      return count.to_f / [ta.stack.length, tb.stack.length].max.to_f
    end


    # Compute distance of modifier list ONLY between two SemTags
    #
    # Uses an edit distance mechanic to score missing items from
    # both sets.
    #
    # Varies from 0 to 1
    def self.modifier_distance_tag(ta, tb)
      return 0 if ta.modifiers.length == 0 && tb.modifiers.length == 0
      count = 0

      # Multi-word status
      count += 1 if ta.multi_word? != tb.multi_word?

      # Count for each different modifier
      (ta.modifiers + tb.modifiers).uniq.each do |m|
        count += 1 if ta.modifiers.include?(m) != tb.modifiers.include?(m)
      end

      return count.to_f / ([ta.modifiers.length, tb.modifiers.length].max + 1).to_f
    end


    # Compute distance of affinity ONLY between two SemTags
    #
    # Ranges from 0 to 1
    def self.affinity_distance_tag(ta, tb)
      raise "affinity must be between -3 and +3 inclusive" unless [ta, tb].map{|x| x.affinity.abs <= 3}.inject{|a, b| a && b}
      return (ta.affinity - tb.affinity).abs.to_f / 6.0
    end

  end


end


