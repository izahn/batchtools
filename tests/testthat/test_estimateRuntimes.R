context("estimateRuntimes")

test_that("estimateRuntimes", {
  reg = makeExperimentRegistry(file.dir = NA, make.default = FALSE)
  addProblem(name = "iris", data = iris, fun = function(data, ...) nrow(data), reg = reg)
  addAlgorithm(name = "nrow", function(instance, ...) nrow(instance), reg = reg)
  addAlgorithm(name = "ncol", function(instance, ...) ncol(instance), reg = reg)
  addExperiments(algo.designs = list(nrow = CJ(x = 1:50, y = letters[1:5])), reg = reg)
  addExperiments(algo.designs = list(ncol = CJ(x = 1:50, y = letters[1:5])), reg = reg)
  tab = getJobPars(reg = reg)

  ids = tab[, .SD[sample(nrow(.SD), 4)], by = c("problem", "algorithm", "y")]
  setkeyv(ids, "job.id")
  submitJobs(s.chunk(ids), reg = reg)
  waitForJobs(reg = reg)

  # "simulate" runtimes
  runtime = function(algorithm, x, y) {
   ifelse(algorithm == "nrow", 100L, 500L) + 100000L * (y %in% letters[1:2])
  }
  reg$status[ids, done := done + tab[ids, runtime(algorithm, x, y), on = "job.id"], on = "job.id"]

  res = estimateRuntimes(tab, reg = reg)
  expect_is(res, "RuntimeEstimate")
  expect_set_equal(names(res), c("runtimes", "model"))
  expect_is(res$model, "ranger")
  expect_data_table(res$runtimes, key = "job.id", nrow = nrow(reg$status))
  expect_output(print(res), "Runtime Estimate for")
  expect_output(print(res, n = 5), "Parallel")

  res = ijoin(res$runtimes, tab)
  res = res[, list(t = mean(runtime)), by = y]
  expect_true(all(res[y == "a", t] > res[y %in% c("c", "d", "e"), t]))

})