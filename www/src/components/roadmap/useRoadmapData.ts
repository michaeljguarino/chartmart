import { Octokit } from '@octokit/core'
import { useCallback, useEffect, useMemo, useState } from 'react'

import { IssueType } from './types'
import { LABEL_REQUEST, LABEL_ROADMAP } from './constants'

const perPage = 100 // Max is 100

function castIssues(rawIssues: any[]): IssueType[] {
  return rawIssues
    .map((issue) => ({
      id: issue.id ?? '',
      title: issue.title ?? '',
      url: issue.html_url ?? '',
      body: issue.body ?? '',
      author: issue.user?.login ?? '',
      state: issue.state ?? '',
      votes: issue.reactions.total_count,
      labels: issue.labels?.map((label: any) => label.name) ?? [],
      isPullRequest: !!issue.pull_request,
      createdAt: issue.created_at ?? '',
      closedAt: issue.closed_at ?? '',
    }))
    .sort((a, b) => (a.createdAt > b.createdAt ? -1 : 1))
}

function useRoadmapData() {
  const [pluralIssues, setPluralIssues] = useState<any[]>([])
  const [pluralArtifactsIssues, setPluralArtifactsIssues] = useState<any[]>([])
  const [pluralConsoleIssues, setPluralConsoleIssues] = useState<any[]>([])
  const [pluralCliIssues, setPluralCliIssues] = useState<any[]>([])
  const [pagePlural, setPagePlural] = useState(0)
  const [pagePluralArtifacts, setPagePluralArtifacts] = useState(0)
  const [pagePluralConsole, setPagePluralConsole] = useState(0)
  const [pagePluralCli, setPagePluralCli] = useState(0)
  const [hasMorePlural, setHasMorePlural] = useState(false)
  const [hasMorePluralArtifacts, setHasMorePluraArtifacts] = useState(false)
  const [hasMorePluralConsoles, setHasMorePluralConsoles] = useState(false)
  const [hasMorePluralClis, setHasMorePluralClis] = useState(false)

  const ockokit = useMemo(() => new Octokit(), [])

  const getPluralIssues = useCallback(async () => {
    const response1 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_ROADMAP}&state=all&page=${pagePlural}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'plural',
      }
    )
    const response2 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_REQUEST}&state=all&page=${pagePlural}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'plural',
      }
    )

    setPluralIssues((x) => [...x, ...response1.data, ...response2.data])
    setHasMorePlural(
      response1.data.length >= perPage || response2.data.length >= perPage
    )
  }, [ockokit, pagePlural])

  const getPluralArtifactsIssues = useCallback(async () => {
    const response1 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_ROADMAP}&state=all&page=${pagePluralArtifacts}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'plural-artifacts',
      }
    )
    const response2 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_REQUEST}&state=all&page=${pagePluralArtifacts}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'plural-artifacts',
      }
    )

    setPluralArtifactsIssues((x) => [
      ...x,
      ...response1.data,
      ...response2.data,
    ])
    setHasMorePluraArtifacts(
      response1.data.length >= perPage || response2.data.length >= perPage
    )
  }, [ockokit, pagePluralArtifacts])

  const getPluralConsoleIssues = useCallback(async () => {
    const response1 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_ROADMAP}&state=all&page=${pagePluralConsole}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'console',
      }
    )
    const response2 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_REQUEST}&state=all&page=${pagePluralConsole}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'console',
      }
    )

    setPluralConsoleIssues((x) => [...x, ...response1.data, ...response2.data])
    setHasMorePluralConsoles(
      response1.data.length >= perPage || response2.data.length >= perPage
    )
  }, [ockokit, pagePluralConsole])

  const getPluralCliIssues = useCallback(async () => {
    const response1 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_ROADMAP}&state=all&page=${pagePluralCli}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'plural-cli',
      }
    )
    const response2 = await ockokit.request(
      `GET /repos/{owner}/{repo}/issues?labels=${LABEL_REQUEST}&state=all&page=${pagePluralCli}&per_page=${perPage}`,
      {
        owner: 'pluralsh',
        repo: 'plural-cli',
      }
    )

    setPluralCliIssues((x) => [...x, ...response1.data, ...response2.data])
    setHasMorePluralClis(
      response1.data.length >= perPage || response2.data.length >= perPage
    )
  }, [ockokit, pagePluralCli])

  useEffect(() => {
    getPluralIssues()
    getPluralArtifactsIssues()
    getPluralConsoleIssues()
    getPluralCliIssues()
  }, [
    getPluralIssues,
    getPluralArtifactsIssues,
    getPluralConsoleIssues,
    getPluralCliIssues,
  ])

  useEffect(() => {
    if (hasMorePlural) setPagePlural((x) => x + 1)
  }, [hasMorePlural])

  useEffect(() => {
    if (hasMorePluralArtifacts) setPagePluralArtifacts((x) => x + 1)
  }, [hasMorePluralArtifacts])

  useEffect(() => {
    if (hasMorePluralConsoles) setPagePluralConsole((x) => x + 1)
  }, [hasMorePluralConsoles])

  useEffect(() => {
    if (hasMorePluralClis) setPagePluralCli((x) => x + 1)
  }, [hasMorePluralClis])

  return {
    pluralIssues: castIssues(pluralIssues),
    pluralArtifactsIssues: castIssues(pluralArtifactsIssues),
    pluralConsoleIssues: castIssues(pluralConsoleIssues),
    pluralCliIssues: castIssues(pluralCliIssues),
  }
}

export default useRoadmapData
