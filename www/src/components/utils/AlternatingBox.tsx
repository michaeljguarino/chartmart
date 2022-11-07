import { useCallback, useState } from 'react'
import { Box } from 'grommet'

const slideAnimate = type => ({
  type, duration: 150, delay: 0, size: 'xlarge',
})

function Content({ children, slide }: any) {
  return (
    <Box
      flex={false}
      animation={slideAnimate(slide) as any}
    >
      {children}
    </Box>
  )
}

export function AlternatingBox({ children }: any) {
  const [opened, setOpened] = useState(false)
  const [alternate, setAlternate] = useState<any>(null)
  const doSetAlternate = useCallback(alternate => {
    setOpened(true)
    setAlternate(alternate)
  }, [setOpened, setAlternate])

  if (!opened && !alternate) return children(doSetAlternate)

  if (alternate) {
    return (
      <Content slide="slideRight">{alternate}</Content>
    )
  }

  return <Content slide="slideLeft">{children(doSetAlternate)}</Content>
}
