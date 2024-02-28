import sys
import os
import re


import pandas as pd
import pandas as pd
import matplotlib.pyplot as plt
import plotly.offline as py
import plotly.tools as tls


def contains_number(line):
   # Regular expression pattern to match any number
   pattern = r'\d+\.?\d*|\.\d+'
  
   # Search for the pattern in the line
   return bool(re.search(pattern, line))


def read_result_lines(results_file: str, start_pattern: str):
   start_line = None
   result_lines = []
   with open(results_file, 'r') as infile:
       for i,line in enumerate(infile):
           if line.replace(' ','').startswith(start_pattern):
               result_lines = [line]
           if contains_number(line):
               result_lines.append(line)


       return result_lines


def write_lines_to_file(lines: list, file_path: str):
   with open(file_path, 'w') as file:
       for line in lines:
           file.write(line.rstrip() + '\n')


def replace_extension(file_path: str, new_extension:str ):
   path, ext = os.path.splitext(file_path)
   return path + '.' + new_extension


def write_lines_to_csv_file(lines: list, file_path: str):
   with open(file_path, 'w') as file:
       for line in lines:
           items = [ item for item in line.rstrip().split(' ') if item ]
           file.write(','.join(items) + '\n')   


def write_lines_to_csv_file(lines: list, file_path: str):
   with open(file_path, 'w') as file:
       for line in lines:
           items = [ item for item in line.rstrip().split(' ') if item ]
           file.write(','.join(items) + '\n')   


def plot_columns_from_csv(csv_path: str):
    # Read the CSV file
    data = pd.read_csv(csv_path)

    # Set the first column as the index (x-axis)
    data.set_index('#bytes', inplace=True)

    # Get the directory of the CSV file
    directory = os.path.dirname(csv_path)

    # Get the column names except the first one
    columns_to_plot = data.columns[1:]

    # Plot each column and save to a file
    for column in columns_to_plot:
        fig = plt.figure()
        plt.plot(data.index, data[column])
        plt.xlabel('Bytes')
        plt.ylabel(column)
        plt.title(f'IMB-MPI1 Benchmark')
        plt.grid(True)
        plt.yscale("log")
        plt.xscale("log")

        # Convert to plotly figure
        fig = plt.gcf()
        plotly_fig = tls.mpl_to_plotly(fig)
        filename = os.path.join(directory, f'{column}.html')
        py.plot(plotly_fig, filename=filename, auto_open=False)



if __name__ == "__main__":
   results_file = sys.argv[1]
   clean_results_file = replace_extension(results_file, 'clean.txt')
   csv_results_file = replace_extension(results_file, 'csv')

   result_lines = read_result_lines(results_file, '#bytes')
   write_lines_to_file(result_lines, clean_results_file)
   write_lines_to_csv_file(result_lines, csv_results_file)
   plot_columns_from_csv(csv_results_file)
