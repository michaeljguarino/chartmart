import React, { useState, useContext, useEffect } from 'react'
import {Box, Text, Anchor, Markdown} from 'grommet'
import Tabs, {TabHeader, TabHeaderItem, TabContent} from '../utils/Tabs'
import {useQuery, useMutation} from 'react-apollo'
import {useParams} from 'react-router-dom'
import Scroller from '../utils/Scroller'
import {CHART_Q, INSTALL_CHART, UPDATE_CHART_INST} from './queries'
import moment from 'moment'
import {DEFAULT_CHART_ICON} from './constants'
import Highlight from 'react-highlight.js'
import Installation from './Installation'
import Button from '../utils/Button'
import {BreadcrumbContext} from '../Chartmart'
import Dependencies, {FullDependencies, ShowFull} from './Dependencies'
import ScrollableContainer from '../utils/ScrollableContainer'

function ChartVersion({version, onSelect}) {
  return (
    <Box direction='row' align='center' gap='xsmall'>
      <Anchor size='small' onClick={() => onSelect(version)}>
        {version.version}
      </Anchor> - <Text size='small'>{moment(version.insertedAt).fromNow()}</Text>
    </Box>
  )
}

function ChartInfo({helm, insertedAt}) {
  return (
    <Box pad='small' elevation='small' gap='small' style={{overflow: 'hidden'}}>
      <Text weight="bold" size='small'>App Version</Text>
      <Text size='small'>{helm.appVersion}</Text>
      <Text weight='bold' size='small'>Created</Text>
      <Text size='small'>{moment(insertedAt).fromNow()}</Text>
      <Text weight='bold' size='small'>Source</Text>
      <Text size='small'>{(helm.sources || []).map((l) => <Anchor key={l} href={l}>{l}</Anchor>)}</Text>
      <Text weight='bold' size='small'>Maintainers</Text>
      <Text size='small'>{(helm.maintainers || []).map((m) => <Box key={m.email}>{m.email}</Box>)}</Text>
    </Box>
  )
}

function Code({value, children, language}) {
  return (
    <Highlight language={language}>
      {value || children}
    </Highlight>
  )
}

export const MARKDOWN_STYLING = {
  p: {props: {size: 'small', style: {maxWidth: '100%'}, margin: {top: 'xsmall', bottom: 'xsmall'}}},
  h1: {props: {style: {borderBottom: '1px solid #eaecef', paddingBottom: '.3em', maxWidth: '100%'}, size: 'small', margin: {top: 'small', bottom: 'small'}}},
  h2: {props: {style: {borderBottom: '1px solid #eaecef', paddingBottom: '.3em', maxWidth: '100%'}, size: 'xsmall', margin: {top: 'small', bottom: 'small'}}},
  pre: {
    component: Code,
    props: {}
  }
}

function TemplateView({valuesTemplate}) {
  return (
    <Box style={{overflow: 'auto', maxHeight: '100%'}} pad='small'>
      <Highlight language='yaml'>
        {valuesTemplate || 'no values template'}
      </Highlight>
    </Box>
  )
}

function ChartInstaller({chartInstallation, versionId, chartId, installation}) {
  const [mutation, {error}] = useMutation(chartInstallation ? UPDATE_CHART_INST : INSTALL_CHART, {
    variables: {
      id: chartInstallation ? chartInstallation.id : installation.id,
      attributes: {chartId, versionId}
    },
    update: (cache, {data}) => {
      const ci = data.installChart || data.updateChartInstallation
      const prev = cache.readQuery({ query: CHART_Q, variables: {chartId} })
      cache.writeQuery({query: CHART_Q, variables: {chartId}, data: {
        ...prev,
        chart: {
          ...prev.chart,
          installation: ci
        }
      }})
    }
  })

  return (
    <Button
      round='xsmall'
      label='Install'
      pad='small'
      error={error}
      onClick={mutation} />
  )
}

function ChartHeader({helm, chart, version, chartInstallation, id, installation}) {
  return (
    <Box direction='row' align='center' gap='small' margin={{bottom: 'small'}} style={{minHeight: '50px'}}>
      <Box width='50px' heigh='50px'>
        <img alt='' width='50px' height='50px' src={chart.icon || DEFAULT_CHART_ICON} />
      </Box>
      <Box width='100%'>
        <Text size='medium'>{chart.name} - {version}</Text>
        <Text size='small'><i>{helm.description}</i></Text>
      </Box>
      <Box width='100px' direction='row' justify='end'>
      {chartInstallation && chartInstallation.version.id === id ?
        <Box round='xsmall' pad='small' border>Installed</Box> :
        installation && (<ChartInstaller
          chartInstallation={chartInstallation}
          installation={installation}
          versionId={id}
          chartId={chart.id} />)
      }
      </Box>
    </Box>

  )
}

function ChartReadme({readme}) {
  return (
    <Box gap='small' pad='small' style={{maxHeight: '100%', overflow: 'auto'}}>
      <Box>
        <Markdown components={MARKDOWN_STYLING}>
          {readme || 'no readme'}
        </Markdown>
      </Box>
    </Box>
  )
}

function updateInstallation(chartId) {
  return (cache, repoId, installation) => {
    const prev = cache.readQuery({query: CHART_Q, variables: {chartId}})
    cache.writeQuery({
      query: CHART_Q,
      variables: {chartId},
      data: {...prev, chart: {...prev.chart, repository: {...prev.chart.repository, installation: installation}}}
    })
  }
}

function Chart() {
  const {chartId} = useParams()
  const [version, setVersion] = useState(null)
  const [tab, setTab] = useState(false)
  const [full, setFull] = useState(false)
  const {loading, data, fetchMore} = useQuery(CHART_Q, {variables: {chartId}})
  const {setBreadcrumbs} = useContext(BreadcrumbContext)
  useEffect(() => {
    if (!data) return
    const {chart} = data
    setBreadcrumbs([
      {url: `/publishers/${chart.repository.publisher.id}`, text: chart.repository.publisher.name},
      {url: `/repositories/${chart.repository.id}`, text: chart.repository.name},
      {url: `/charts/${chart.id}`, text: chart.name}
    ])
  }, [data, setBreadcrumbs])

  if (loading || !data) return null

  const {versions, chart} = data
  const repository = chart.repository
  const {edges, pageInfo} = versions
  const currentVersion = version || edges[0].node
  const width = tab === 'configuration' ? 65 : 70

  return (
    <ScrollableContainer>
      <Box pad='small' direction='row'>
        <Box width={`${width}%`} pad='small'>
          <ChartHeader {...currentVersion} chartInstallation={data.chart.installation} installation={repository.installation} />
          <Tabs defaultTab='readme' onTabChange={setTab} headerEnd={tab === 'dependencies' ?
            <ShowFull label={full ? 'Immediate' : 'Full'} onClick={() => setFull(!full)} /> : null
          }>
            <TabHeader>
              <TabHeaderItem name='readme'>
                <Text style={{fontWeight: 500}} size='small'>Readme</Text>
              </TabHeaderItem>
              <TabHeaderItem name='configuration'>
                <Text style={{fontWeight: 500}} size='small'>Configuration</Text>
              </TabHeaderItem>
              <TabHeaderItem name='dependencies'>
                <Text size='small' style={{fontWeight: 500}}>Dependencies</Text>
              </TabHeaderItem>
            </TabHeader>
            <TabContent name='readme'>
              <ChartReadme {...currentVersion} />
            </TabContent>
            <TabContent name='configuration'>
              <TemplateView {...currentVersion} />
            </TabContent>
            <TabContent name='dependencies'>
              {full ? <FullDependencies {...chart} /> : <Dependencies {...chart} />}
            </TabContent>
          </Tabs>
        </Box>
        <Box pad='small' width={`${100 - width}%`} gap='small'>
          {tab === 'configuration' ? <Installation repository={repository} onUpdate={updateInstallation(chartId)} open /> :
            (<>
            <Box elevation='small' gap='xsmall' pad='small' style={{maxHeight: '50%'}}>
              <Text size='small' weight='bold'>Versions</Text>
              <Scroller id='chart'
                edges={edges}
                style={{overflow: 'auto', width: '100%'}}
                mapper={({node}, next) => <ChartVersion key={node.id} version={node} hasNext={!!next} onSelect={setVersion} />}
                onLoadMore={() => {
                  if (!pageInfo.hasNextPage) return

                  fetchMore({
                    variables: {chartCursor: pageInfo.endCursor},
                    updateQuery: (prev, {fetchMoreResult}) => {
                      const {edges, pageInfo} = fetchMoreResult.versions
                      return edges.length ? {
                        ...prev,
                        versions: {
                          ...prev.versions,
                          pageInfo,
                          edges: [...prev.versions.edges, ...edges]
                        }
                      } : prev
                    }
                  })
                }} />
            </Box>
            <ChartInfo {...currentVersion} />
            </>)}
        </Box>
      </Box>
    </ScrollableContainer>
  )
}

export default Chart