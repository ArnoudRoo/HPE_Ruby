require_relative 'pe'
require_relative 'core/environment/store'
require_relative 'core/environment/store_var'
require_relative 'store_test'
require 'fileutils'

def initializeDirs
  FileUtils.rm_rf("..\\output", secure: true)
  FileUtils.mkdir "..\\output"
end

#loop through all the files in the input dir and partial evaluate the files
#and put the residual code in the output folder
def partialEvaluateFiles
  pe = PE.new()
  Dir.foreach('..\input') { |file|
    if (File.fnmatch("*.rb", file))

      puts "Start pe of #{file}"

      residualCode = pe.run(nil, "..\\input\\#{file}")

      #print the residual code to file.
      File.open("..\\output\\#{file}", "w") do |f|
        f.write residualCode
      end
    end
  }
end

def checkPartialEvaluatedFiles
  Dir.foreach('..\ExpectedOutput') { |file|
    if (File.fnmatch("*.rb", file))

      if (File.exist? "..\\output\\#{file}")
        same = FileUtils.compare_file("..\\output\\#{file}", "..\\expectedOutput\\#{file}")
        puts "#{file} not identical" if !same
      else
        puts "#{file} doesn't exist in the output folder.'"
      end

    end
  }
end

def compareResults
  Dir.foreach('..\input') { |file|
    if (File.fnmatch("*.rb", file))

      org = "..\\input\\#{file}"
      res = "..\\output\\#{file}"

      system("ruby #{org} > ..\\org.txt")
      system("ruby #{res} > ..\\res.txt")

      same = FileUtils.compare_file("..\\org.txt","..\\res.txt")
      puts "#{file} has not the same output" if !same

    end
  }
end


#run the unit tests.
#st = StoreTest.new()
#st.run

initializeDirs
partialEvaluateFiles
checkPartialEvaluatedFiles
compareResults


