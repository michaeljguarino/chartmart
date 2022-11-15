import { useMemo, useState } from 'react'
import { ResponsiveLine } from '@nivo/line'
import moment from 'moment'
import last from 'lodash/last'
import { Box, Text } from 'grommet'
import { Flex, P } from 'honorable'
import { semanticColors } from '@pluralsh/design-system/dist/theme/colors'

export function dateFormat(date) {
  return moment(date).format('MM/DD h:mm:ss A')
}

export function GraphHeader({ text }: any) {
  return (
    <Box
      direction="row"
      align="center"
      justify="center"
    >
      <Text
        size="small"
        weight="bold"
      >{text}
      </Text>
    </Box>
  )
}

function SliceTooltip({ point: { serieColor, serieId, data } }: any) {
  return (
    <Flex
      background="fill-one"
      border="1px solid border"
      borderRadius="4px"
      paddingVertical="xxsmall"
      paddingHorizontal="xsmall"
      direction="row"
      gap="xsmall"
      align="center"
    >
      <Flex
        width="10px"
        height="10px"
        borderRadius="50%"
        backgroundColor={serieColor}
      />
      <P body2>{serieId} [x: {data.xFormatted}, y: {data.yFormatted}]</P>
    </Flex>
  )
}

export const DURATIONS = [
  {
    offset: '7d', step: '2h', label: '7d', tick: 'every 12 hours',
  },
  {
    offset: '30d', step: '1d', label: '30d', tick: 'every 2 days',
  },
  {
    offset: '60d', step: '1d', label: '60d', tick: 'every 5 days',
  },
  {
    offset: '120d', step: '1d', label: '120d', tick: 'every 10 day',
  },
]

export function Graph({ data, yFormat, tick }: any) {
  const [selected, setSelected] = useState<any>(null)
  const graph = useMemo(() => {
    if (data.find(({ id }) => id === selected)) {
      return data.filter(({ id }) => id === selected)
    }

    return data
  }, [data, selected])

  if (graph.length === 0) return <Text size="small">No data available.</Text>

  const hasData = !!graph[0].data[0]

  return (
    <ResponsiveLine
      data={graph}
      margin={{
        top: 50, right: 110, bottom: 75, left: 70,
      }}
      areaOpacity={0.5}
      useMesh
      lineWidth={2}
      enablePoints={false}
      enableGridX={false}
      animate={false}
      xScale={{ type: 'time', format: 'native' }}
      yScale={{
        type: 'linear', min: 'auto', max: 'auto', stacked: false, reverse: false,
      }}
      colors={data => data.color}
      yFormat={yFormat}
      xFormat={dateFormat}
      tooltip={SliceTooltip}
      axisLeft={{
        orient: 'left',
        tickSize: 5,
        format: yFormat,
        tickPadding: 5,
        tickRotation: 0,
        legendOffset: -50,
        legendPosition: 'start',
      } as any}
      axisBottom={{
        format: '%H:%M',
        tickValues: tick || 'every 5 minutes',
        orient: 'bottom',
        legendPosition: 'middle',
        legend: hasData ? `${dateFormat(data[0].data[0].x)} to ${dateFormat((last(data[0].data) as any).x)}` : null,
        legendOffset: 46,
      } as any}
      pointLabel="y"
      pointLabelYOffset={-15}
      legends={[
        {
          anchor: 'bottom-right',
          onClick: ({ id }) => (selected ? setSelected(null) : setSelected(id)),
          direction: 'column',
          justify: false,
          translateX: 100,
          translateY: 0,
          itemsSpacing: 0,
          itemDirection: 'left-to-right',
          itemWidth: 80,
          itemHeight: 20,
          symbolSize: 12,
          symbolShape: 'circle',
          itemTextColor: semanticColors['text-xlight'],
          effects: [
            {
              on: 'hover',
              style: {
                itemBackground: 'rgba(0, 0, 0, .03)',
                itemTextColor: semanticColors['text-light'],
              },
            },
          ],
        },
      ]}
      theme={{
        axis: {
          ticks: {
            text: {
              fill: semanticColors['text-xlight'],
            },
            line: {
              stroke: semanticColors.border,
            },
          },
          legend: {
            text: {
              fill: semanticColors['text-xlight'],
            },
          },
        },
        grid: {
          line: {
            stroke: semanticColors.border,
          },
        },
      }}
    />
  )
}
