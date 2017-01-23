require 'spec_helper'

describe 'CycleAnalytics#plan', feature: true do
  extend CycleAnalyticsHelpers::TestGeneration

  let(:project) { create(:project) }
  let(:from_date) { 10.days.ago }
  let(:user) { create(:user, :admin) }
  subject { CycleAnalytics.new(project, from: from_date) }

  generate_cycle_analytics_spec(
    phase: :plan,
    data_fn: -> (context) do
      {
        issue: context.create(:issue, project: context.project),
        branch_name: context.random_git_name
      }
    end,
    start_time_conditions: [["issue associated with a milestone",
                             -> (context, data) do
                               data[:issue].update(milestone: context.create(:milestone, project: context.project))
                             end],
                            ["list label added to issue",
                             -> (context, data) do
                               data[:issue].update(label_ids: [context.create(:label, lists: [context.create(:list)]).id])
                             end]],
    end_time_conditions:   [["issue mentioned in a commit",
                             -> (context, data) do
                               context.create_commit_referencing_issue(data[:issue], branch_name: data[:branch_name])
                             end]],
    post_fn: -> (context, data) do
      context.create_merge_request_closing_issue(data[:issue], source_branch: data[:branch_name])
      context.merge_merge_requests_closing_issue(data[:issue])
    end)

  context "when a regular label (instead of a list label) is added to the issue" do
    it "returns nil" do
      branch_name = random_git_name
      label = create(:label)
      issue = create(:issue, project: project)
      issue.update(label_ids: [label.id])
      create_commit_referencing_issue(issue, branch_name: branch_name)

      create_merge_request_closing_issue(issue, source_branch: branch_name)
      merge_merge_requests_closing_issue(issue)

      expect(subject[:issue].median).to be_nil
    end
  end
end
