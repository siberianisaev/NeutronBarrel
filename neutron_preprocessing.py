import pandas as pd
import numpy as np


class ExpProcessing:
    """
    class for preprocessed neutrons experiment data
    """

    def __init__(self, counts_measured):
        """
        Input : counts_measured - list (or any numpy convertible type)
        Method creates a data frame with experimental counts, its errors,
        normed values and its errors, mean and variance of the spectra
        The data frame consists the next columns:
        ["bin", "count", "count_error", "probability", "probability_error",
         "relative_error", "mean", "mean_error", "variance"]
        """
        self._data = pd.DataFrame(columns=["bin", "count", "count_error", "probability",
                                           "probability_error", "relative_error",
                                           "mean", "mean_error", "variance"])
        if not isinstance(counts_measured, np.ndarray):
            try:
                counts_measured = np.array(counts_measured)
            except TypeError:
                raise TypeError("count_measured must be an array or any numpy convertible type")
        if counts_measured.size < 10:
            counts_measured = np.pad(counts_measured, (0, 10 - counts_measured.size))
        self._data["bin"] = [i for i in range(counts_measured.size)]
        self._data["count"] = counts_measured
        self._data["count_error"] = self.count_error_calculation()
        self._data["relative_error"] = self._data["count_error"] / self._data["count"]
        self._data["probability"], self._data["probability_error"] = self.normalization()
        self._data["mean"] = self.mean_calculation()
        self._data["mean_error"] = self.calculate_error_of_mean()
        self._data["variance"] = self.variance_calculation()

    def count_error_calculation(self):
        """
        Method returns errors of experimental points s
        s = sqrt(N) / sqrt(k), for k >= 1
        s = sqrt(N) for k = 0
        where N - counts of events with multiplicity k,
        k - multiplicity of event
        :return: array of absolute errors
        """
        counts, bins = self._data["count"], self._data["bin"]
        return [(N / k) ** 0.5 if k > 1 else N ** 0.5 for N, k in zip(counts, bins)]

    def normalization(self):
        """
        Method converts experimental points and errors to
        probability of neutron emission and its errors
        :return: two arrays: array of neutron emissions probability and its errors
        """
        counts = self._data["count"]
        count_errors = self._data["count_error"]
        total = counts.sum()
        return counts / total, count_errors / total

    def mean_calculation(self):
        """
        Method calculates mean value of experimental spectra
        mean = total_neutrons / total_events
        :return: mean value
        """
        bins = self._data["bin"]
        counts = self._data["count"]
        return bins.dot(counts).sum() / counts.sum()

    def variance_calculation(self):
        """
        Method calculates variance of experimental spectra
        variance = mean()**2 - mean(data**2)
        :return: variance
        """
        bins, counts = self._data["bin"], self._data["count"]
        mx2 = (bins*bins).dot(counts).sum() / counts.sum()
        m = self._data["mean"][0]
        return mx2 - m * m

    def get_data(self):
        """
        Method returns the data in pandas.DataFrame format
        :return: pandas.DataFrame object
        """
        return self._data

    def to_csv(self, filename=""):
        """
        Method saves all calculated data to .csv file
        with name 'filename'
        :param filename: otional, name of file, default is 'neutrons+{current_date_and_time}.csv'
        """
        if filename == "":
            from datetime import datetime
            now = datetime.now().strftime("%Y_%m_%d_%H_%M")
            filename = f"neutrons_{now}.csv"
        try:
            self._data.to_csv(filename, index=False, header=True)
            print(filename + " was saved successfully")
        except FileNotFoundError as ex:
            print("########\n# No such directory! Unsuccessful writing!\n########")

    def calculate_error_of_mean(self):
        """
        Method calculates the statistical error of measured mean value.
        dM^2= (dN / E)^2 + (N * dE / E^2)^2
        dM - mean error
        N, dN - number of neutrons and its error (dN = sqrt(N))
        E, dE - number of events and its error (dE = sqrt(E))
        :return: dM, error of measured mean value
        """
        total_events = self._data["count"].sum()
        total_neutrons = self._data["count"].dot(self._data["bin"]).sum()
        delta_events = total_events ** 0.5
        delta_neutrons = total_neutrons ** 0.5
        delta_mean_sq = (delta_neutrons / total_events)**2 + \
                        (total_neutrons * delta_events / total_events**2)**2
        return delta_mean_sq ** 0.5


if __name__ == "__main__":
    folder = "csv_05_2021/"
    file = "Fm244" + ".csv"
    a = [10, 20, 30]
    pd.set_option('display.max_columns', None)
    b = ExpProcessing(a)
    print(b.get_data())
    print(b.calculate_error_of_mean())
    # b.to_csv(folder + file)
