import csv
import numpy as np
import matplotlib.pyplot as plt

def generate_stacked_bar_plot(csv_file):
    # Read CSV file and extract data
    data = []
    exams = set()  # Set to store unique exam names
    with open(csv_file, 'r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            roll_number = row['Roll_Number']
            name = row['Name']
            student_marks = []
            total_marks = 0
            for exam, mark in row.items():
                if exam not in ['Roll_Number', 'Name']:
                    if mark is None or not mark.isdigit():
                        mark = '0'  # Replace None or non-numeric values with 0
                    student_marks.append(int(mark))
                    exams.add(exam)
                    total_marks += int(mark)
            # Pad student_marks with zeros if it's shorter than the number of exams
            student_marks += [0] * (len(exams) - len(student_marks))
            data.append((roll_number, name, student_marks, total_marks))

    # Sort data by total marks
    data.sort(key=lambda x: x[3], reverse=True)

    # Prepare data for plotting
    students = [student[1] for student in data]
    exam_marks = np.array([student[2] for student in data])
    total_marks = np.array([student[3] for student in data])

    # Generate stacked bar plot
    plt.figure(figsize=(12, 8))
    bars = []
    colors = plt.cm.viridis(np.linspace(0, 1, len(exams)))  # Generate color map for exams
    left = np.zeros(len(students))
    for i, exam in enumerate(sorted(exams)):
        marks = exam_marks[:, i]
        bars.append(plt.barh(students, marks, left=left, color=colors[i], label=exam))
        left += marks  # Update left position for next exam

    plt.xlabel('Marks')
    plt.ylabel('Students')
    plt.title('Marks Distribution of Students in Different Exams')
    plt.legend()

    # Display total marks on each bar
    for bar, total_mark in zip(bars[0], total_marks):
        plt.text(bar.get_width(), bar.get_y() + bar.get_height() / 2, f'Total: {total_mark}', va='center')

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    csv_file = "main.csv"
    generate_stacked_bar_plot(csv_file)
