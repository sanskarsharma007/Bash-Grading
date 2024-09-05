import csv
import numpy as np

def calculate_statistics(csv_file):
    # Read CSV file and extract marks
    marks = []
    with open(csv_file, 'r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            # Convert dict_values to list before accessing elements
            mark_list = list(row.values())
            # Check for None values and convert to np.nan
            marks.append([int(mark) if mark and mark.isdigit() else 0 for mark in mark_list[2:]])

    # Calculate statistics
    means = np.nanmean(marks, axis=1)
    medians = np.nanmedian(marks, axis=1)
    std_devs = np.nanstd(marks, axis=1)

    # Print statistics
    print("Statistics:")
    for i, (mean, median, std_dev) in enumerate(zip(means, medians, std_devs), start=1):
        print(f"Student {i}: Mean = {mean:.2f}, Median = {median}, Standard Deviation = {std_dev:.2f}")

if __name__ == "__main__":
    csv_file = "main.csv"
    calculate_statistics(csv_file)
