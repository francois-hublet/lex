type processingid is int
type processorid is int
type dataid is int

# observable event
# causable event
# internal event
suppressable event PersonalDataProcessing
    """
    {x} is processing personal data {z} as part
    of processing operation {ep}

    @x is processing personal data @z as part of
    processing operation @ep
    """
    ep: processingid
    x: processorid
    z: dataid

# causable event EventWithoutParameters
#     """ """
# docstring should be optional

causable event EventWithoutDocstringOrParameters
    # a: string
# (this event definition is rejected by the parser: missing parameters)
